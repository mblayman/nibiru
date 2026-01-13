#include <errno.h>
#include <fcntl.h>
#include <lauxlib.h>
#include <libgen.h>
#include <limits.h>
#include <lua.h>
#include <lualib.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>

// For memmem function
#define _GNU_SOURCE
#include <string.h>

#include "parse.h"
#include "static.h"

// Feature detection for accept4 (Linux-specific with _GNU_SOURCE)
#if defined(__linux__) && defined(_GNU_SOURCE)
#define HAVE_ACCEPT4 1
int accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags);
#endif

// Static file configuration
char *static_dir = "static";
char *static_url = "/static";

struct WorkerState {
    // The local Lua interpreter
    lua_State *lua_state;
    // The WSGI application callable
    int application_reference;
    // The connection handler within nibiru's Lua code
    int handle_connection_reference;
};

#define MAX_WORKERS 64

// Global flag for graceful shutdown
volatile sig_atomic_t shutdown_requested = 0;

// Worker shutdown flag
volatile sig_atomic_t worker_shutdown_requested = 0;

// Signal handler for graceful shutdown
void signal_handler(int signum) {
    (void)signum;
    shutdown_requested = 1;
}

// Signal handler for worker shutdown
void worker_signal_handler(int signum) {
    (void)signum;
    worker_shutdown_requested = 1;
}

// Forward declarations
int send_completion_to_parent(int unix_socket);
int receive_completion_from_worker(int unix_socket);

struct WorkerPool {
    int num_workers;
    pid_t worker_pids[MAX_WORKERS];
};

/**
 * Load a Lua module and store a specified module function into the Lua
 * registry.
 * @param lua_state The Lua state object
 * @param module_name The Lua module to load
 * @param function_name The function within the module
 * @return The function's reference in the Lua registry or -1 on failure.
 */
int nibiru_load_registered_lua_function(lua_State *lua_state,
                                        const char *module_name,
                                        const char *function_name) {
    lua_getglobal(lua_state, "require");
    lua_pushstring(lua_state, module_name);
    int status = lua_pcall(lua_state, 1, 1, 0);
    if (status != LUA_OK) {
        printf("Error: %s\n", lua_tostring(lua_state, -1));
        return -1;
    }

    int lua_type = lua_getfield(lua_state, -1, function_name);
    if (lua_type != LUA_TFUNCTION) {
        printf("Unexpected type: %s is not a function.", function_name);
        return -1;
    }

    int function_reference = luaL_ref(lua_state, LUA_REGISTRYINDEX);

    // Take the module off the stack to clean up.
    lua_pop(lua_state, 1);

    return function_reference;
}

/**
 * Check that the value at the top of the Lua stack is callable.
 * @param lua_state The Lua state object
 * @return 1 if callable else 0
 */
int is_callable(lua_State *lua_state) {
    int status = lua_isfunction(lua_state, -1);
    if (status == 1) {
        return 1;
    }

    if (lua_istable(lua_state, -1) || lua_isuserdata(lua_state, -1)) {
        if (lua_getmetatable(lua_state, -1)) {
            lua_pushstring(lua_state, "__call");
            lua_rawget(lua_state, -2);

            // Check if the __call field is a function
            int is_callable = lua_isfunction(lua_state, -1);

            // Pop the __call field and the metatable from the stack
            lua_pop(lua_state, 2);

            return is_callable;
        }
    }

    return 0;
}

int initialize_worker(struct WorkerState *worker, const char *app_module,
                      const char *app_name) {
    worker->lua_state = NULL;
    worker->application_reference = 0;
    worker->handle_connection_reference = 0;

    int status;

    worker->lua_state = luaL_newstate();
    luaL_openlibs(worker->lua_state);

    // Load the bootstrap module to get the WSGI callable.
    int bootstrap_reference = nibiru_load_registered_lua_function(
        worker->lua_state, "nibiru.server.boot", "bootstrap");
    if (bootstrap_reference == -1) {
        return 1;
    }

    lua_rawgeti(worker->lua_state, LUA_REGISTRYINDEX, bootstrap_reference);
    lua_pushstring(worker->lua_state, app_module);
    lua_pushstring(worker->lua_state, app_name);
    status = lua_pcall(worker->lua_state, 2, 1, 0);
    if (status != LUA_OK) {
        printf("Error: %s\n", lua_tostring(worker->lua_state, -1));
        return 1;
    }
    status = is_callable(worker->lua_state);
    if (status == 0) {
        printf("`%s` is not a valid callable.\n", app_name);
        return 1;
    }
    worker->application_reference =
        luaL_ref(worker->lua_state, LUA_REGISTRYINDEX);

    // Load the connection handler.
    int handle_connection_reference = nibiru_load_registered_lua_function(
        worker->lua_state, "nibiru.server.connector", "handle_connection");
    if (handle_connection_reference == -1) {
        return 1;
    }
    worker->handle_connection_reference = handle_connection_reference;

    return 0;
}

void free_worker(struct WorkerState *worker) {
    if (worker->lua_state != NULL) {
        lua_close(worker->lua_state);
    }
}

int run_worker(int worker_id, int listen_socket_fd, pid_t main_pid,
               const char *app_module, const char *app_name) {
    // Set up signal handler for graceful shutdown
    struct sigaction sa;
    sa.sa_handler = worker_signal_handler;
    sa.sa_flags = 0;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGTERM, &sa, NULL);

    // Ignore SIGPIPE (broken pipe from client disconnects)
    sa.sa_handler = SIG_IGN;
    sigaction(SIGPIPE, &sa, NULL);

    // Initialize worker state
    struct WorkerState worker;
    int status = initialize_worker(&worker, app_module, app_name);
    if (status != 0) {
        free_worker(&worker);
        return 1;
    }

    // Worker main loop - accept connections and handle requests
    while (1) {
        // Accept new connection
        struct sockaddr_storage client_addr;
        socklen_t addr_size = sizeof(client_addr);
        int client_fd;
        client_fd = accept(listen_socket_fd, (struct sockaddr *)&client_addr,
                           &addr_size);
        if (client_fd != -1) {
            fcntl(client_fd, F_SETFD, FD_CLOEXEC);
        }
        if (client_fd == -1) {
            if (errno == EINTR) {
                if (worker_shutdown_requested) {
                    break;
                }
                continue; // Interrupted, try again
            }
            // Socket closed or error - exit gracefully
            printf("Worker %d: Accept failed or socket closed, shutting down\n",
                   worker_id);
            break;
        }

        // Processing HTTP request

        // TODO: This should probably be much larger and configurable.
        int receive_buffer_size = 10000;
        char receive_buffer[receive_buffer_size];

        // Handle the HTTP request
        int bytes_received =
            recv(client_fd, receive_buffer, receive_buffer_size, 0);
        if (bytes_received > 0) {
            // Add null to terminate the C string from Lua's point of view.
            receive_buffer[bytes_received] = '\0';

            // Parse the HTTP request line
            const char *method, *target, *version;
            int method_len, target_len, version_len;
            int parse_result = parse_request_line(
                receive_buffer, bytes_received, &method, &target, &version,
                &method_len, &target_len, &version_len);

            // Handle parsing errors
            if (parse_result == -1 || parse_result == -3) {
                // Malformed request: no CRLF found (-1) or leading whitespace
                // (-3)
                const char *error_response = "HTTP/1.1 400 Bad Request\r\n\r\n";
                send(client_fd, error_response, strlen(error_response), 0);
                close(client_fd);
                continue;
            } else if (parse_result == -2) {
                // Method or version not supported
                const char *error_response;
                if (!is_supported_method(method, method_len)) {
                    error_response = "HTTP/1.1 501 Not Implemented\r\n\r\n";
                } else {
                    error_response =
                        "HTTP/1.1 505 HTTP Version Not Supported\r\n\r\n";
                }
                send(client_fd, error_response, strlen(error_response), 0);
                close(client_fd);
                continue;
            }

            // Check for static file requests
            if (is_static_request(target, static_url)) {
                // Connect to delegation socket
                int delegation_sock = socket(AF_UNIX, SOCK_STREAM, 0);
                if (delegation_sock != -1) {
                    struct sockaddr_un addr;
                    memset(&addr, 0, sizeof(addr));
                    addr.sun_family = AF_UNIX;
                    snprintf(addr.sun_path, sizeof(addr.sun_path),
                             "/tmp/nibiru_static_%d.sock", main_pid);
                    if (connect(delegation_sock, (struct sockaddr *)&addr,
                                sizeof(addr)) == 0) {
                        delegate_static_request(delegation_sock, method,
                                                method_len, target, target_len,
                                                client_fd);
                        // Read response from delegation_sock and send to
                        // client_fd
                        char response_buf[8192];
                        ssize_t n;
                        while ((n = read(delegation_sock, response_buf,
                                         sizeof(response_buf))) > 0) {
                            send(client_fd, response_buf, n, 0);
                        }
                        close(delegation_sock);
                        close(client_fd);
                        continue;
                    } else {
                        perror("Failed to connect to delegation socket");
                    }
                    close(delegation_sock);
                } else {
                    perror("Failed to create delegation socket");
                }
                // Fallback: close connection
                close(client_fd);
                continue;
            }

            // Find the start of remaining data (after \r\n)
            const char *remaining_data =
                memmem(receive_buffer, bytes_received, "\r\n", 2);
            if (remaining_data) {
                remaining_data += 2; // Skip \r\n
            } else {
                remaining_data = ""; // Should not happen if parsing succeeded
            }

            // Process the request with Lua
            lua_rawgeti(worker.lua_state, LUA_REGISTRYINDEX,
                        worker.handle_connection_reference);
            lua_rawgeti(worker.lua_state, LUA_REGISTRYINDEX,
                        worker.application_reference);
            lua_pushlstring(worker.lua_state, method, method_len);
            lua_pushlstring(worker.lua_state, target, target_len);
            lua_pushlstring(worker.lua_state, version, version_len);
            lua_pushstring(worker.lua_state, remaining_data);

            status = lua_pcall(worker.lua_state, 5, 1, 0);
            if (status != LUA_OK) {
                printf("Worker %d: Lua error: %s\n", worker_id,
                       lua_tostring(worker.lua_state, -1));
                // Send a basic error response
                const char *error_response =
                    "HTTP/1.1 500 Internal Server Error\r\n\r\n";
                send(client_fd, error_response, strlen(error_response), 0);
            } else {
                size_t response_length;
                const char *response =
                    lua_tolstring(worker.lua_state, -1, &response_length);
                int bytes_sent = send(client_fd, response, response_length, 0);
                if (bytes_sent == -1) {
                    perror("Worker: send failed");
                }
                lua_pop(worker.lua_state, 1);
            }
        } else if (bytes_received == 0) {
            // Connection closed by client
        } else {
            perror("Worker: recv failed");
        }

        close(client_fd);
    }

    free_worker(&worker);
    return 0;
}

int initialize_worker_pool(struct WorkerPool *pool, int num_workers) {
    pool->num_workers = num_workers;

    // Initialize pids
    for (int i = 0; i < num_workers; i++) {
        pool->worker_pids[i] = -1;
    }

    return 0;
}

void free_worker_pool(struct WorkerPool *pool) {
    for (int i = 0; i < pool->num_workers; i++) {
        if (pool->worker_pids[i] != -1) {
            kill(pool->worker_pids[i], SIGTERM);
        }
    }
}

// Send completion notification from worker to parent
int send_completion_to_parent(int unix_socket) {
    char completion_msg = 'D'; // 'D' for Done
    ssize_t sent = send(unix_socket, &completion_msg, 1, 0);
    if (sent == -1) {
        perror("send completion failed");
        return -1;
    }
    return 0;
}

// Receive completion notification in parent
int receive_completion_from_worker(int unix_socket) {
    char completion_msg;
    ssize_t received = recv(unix_socket, &completion_msg, 1, MSG_DONTWAIT);
    if (received == -1) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            // No message available
            return 0;
        }
        perror("recv completion failed");
        return -1;
    }
    if (received == 0) {
        // Worker closed connection
        return -1;
    }
    if (completion_msg == 'D') {
        return 1; // Completion received
    }
    return 0; // Unknown message
}

/**
 * Detect if we're running from a LuaRocks tree and set up paths accordingly.
 * This checks for the presence of nibiru_core.so relative to the binary
 * location.
 */
void setup_rocks_paths() {
    char exe_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len == -1) {
        // Fallback: try argv[0] if readlink fails
        return;
    }
    exe_path[len] = '\0';

    // Get directory of executable (dirname modifies the string, so copy it
    // first)
    char exe_path_copy[PATH_MAX];
    strcpy(exe_path_copy, exe_path);
    char *exe_dir = dirname(exe_path_copy);

    // Check if this looks like a rocks tree structure
    // From .rocks/bin/nibiru, we expect .rocks/lib/lua/5.x/nibiru_core.so
    char lib_path[PATH_MAX];
    char share_path[PATH_MAX];

    // Try different Lua versions (5.1, 5.2, 5.3, 5.4)
    const char *lua_versions[] = {"5.1", "5.2", "5.3", "5.4", NULL};
    int found = 0;

    for (const char **version = lua_versions; *version != NULL; version++) {
        // Construct path to lib directory
        snprintf(lib_path, sizeof(lib_path), "%s/../lib/lua/%s/nibiru_core.so",
                 exe_dir, *version);
        snprintf(share_path, sizeof(share_path), "%s/../share/lua/%s", exe_dir,
                 *version);

        if (access(lib_path, F_OK) == 0) {
            found = 1;
            break;
        }
    }

    if (!found) {
        // Not in a rocks tree, return
        return;
    }

    // Get current LUA_PATH and LUA_CPATH
    const char *current_lua_path = getenv("LUA_PATH");
    const char *current_lua_cpath = getenv("LUA_CPATH");

    // Construct new paths
    char new_lua_path[4096];
    char new_lua_cpath[4096];

    // LUA_PATH: Add share/lua/5.x/?.lua and share/lua/5.x/?/init.lua
    // Include ;; at the end to append default paths (including current
    // directory)
    if (current_lua_path) {
        snprintf(new_lua_path, sizeof(new_lua_path),
                 "%s/?.lua;%s/?/init.lua;%s;;", share_path, share_path,
                 current_lua_path);
    } else {
        snprintf(new_lua_path, sizeof(new_lua_path), "%s/?.lua;%s/?/init.lua;;",
                 share_path, share_path);
    }

    // LUA_CPATH: Add lib/lua/5.x/?.so
    // Include ;; at the end to append default paths
    char lib_dir[PATH_MAX];
    snprintf(lib_dir, sizeof(lib_dir), "%s/../lib/lua/%s", exe_dir,
             "5.4"); // Use the version we found

    if (current_lua_cpath) {
        snprintf(new_lua_cpath, sizeof(new_lua_cpath), "%s/?.so;%s;;", lib_dir,
                 current_lua_cpath);
    } else {
        snprintf(new_lua_cpath, sizeof(new_lua_cpath), "%s/?.so;;", lib_dir);
    }

    // Set the environment variables
    setenv("LUA_PATH", new_lua_path, 1);
    setenv("LUA_CPATH", new_lua_cpath, 1);
}

int main(int argc, char *argv[]) {
    // Set up paths if running from a LuaRocks tree
    setup_rocks_paths();

    /*
     * Process arguments.
     */
    if (argc < 2) {
        printf("Usage: nibiru run [--workers N] [--static DIR] [--static-url "
               "URL] <app> [port]\n");
        printf("  <app> is in format of: module.path:app\n");
        printf("  --workers N: number of worker processes (default: 2)\n");
        return 1;
    }

    if (strcmp(argv[1], "run") != 0) {
        printf("Unknown subcommand: %s\n", argv[1]);
        printf("Usage: nibiru run [--workers N] [--static DIR] [--static-url "
               "URL] <app> [port]\n");
        printf("  <app> is in format of: module.path:app\n");
        printf("  --workers N: number of worker processes (default: 2)\n");
        return 1;
    }

    // Parse --workers option
    int num_workers = 2; // default
    int arg_offset = 0;

    if (argc >= 3 && strncmp(argv[2], "--workers=", 10) == 0) {
        // Parse --workers=N format
        char *workers_str = argv[2] + 10;
        char *endptr;
        num_workers = strtol(workers_str, &endptr, 10);
        if (*endptr != '\0' || num_workers <= 0) {
            printf("Error: --workers must be a positive integer\n");
            printf("Usage: nibiru run [--workers N] [--static DIR] "
                   "[--static-url URL] <app> [port]\n");
            return 1;
        }
        arg_offset = 1;
    } else if (argc >= 4 && strcmp(argv[2], "--workers") == 0) {
        // Parse --workers N format
        char *endptr;
        num_workers = strtol(argv[3], &endptr, 10);
        if (*endptr != '\0' || num_workers <= 0) {
            printf("Error: --workers must be a positive integer\n");
            printf("Usage: nibiru run [--workers N] [--static DIR] "
                   "[--static-url URL] <app> [port]\n");
            return 1;
        }
        arg_offset = 2;
    }

    // Parse --static option
    if (argc >= 3 + arg_offset &&
        strncmp(argv[2 + arg_offset], "--static=", 9) == 0) {
        static_dir = argv[2 + arg_offset] + 9;
        arg_offset++;
    } else if (argc >= 4 + arg_offset &&
               strcmp(argv[2 + arg_offset], "--static") == 0) {
        static_dir = argv[3 + arg_offset];
        arg_offset += 2;
    }

    // Parse --static-url option
    if (argc >= 3 + arg_offset &&
        strncmp(argv[2 + arg_offset], "--static-url=", 13) == 0) {
        static_url = argv[2 + arg_offset] + 13;
        arg_offset++;
    } else if (argc >= 4 + arg_offset &&
               strcmp(argv[2 + arg_offset], "--static-url") == 0) {
        static_url = argv[3 + arg_offset];
        arg_offset += 2;
    }

    if (argc < 3 + arg_offset) {
        printf("Usage: nibiru run [--workers N] [--static DIR] [--static-url "
               "URL] <app> [port]\n");
        printf("  <app> is in format of: module.path:app\n");
        printf("  --workers N: number of worker processes (default: 2)\n");
        return 1;
    }

    char *app_specifier = argv[2 + arg_offset];
    char *app_module = strsep(&app_specifier, ":");
    char *app_name = strsep(&app_specifier, ":");
    // The default callable name is "app".
    if (app_name == NULL) {
        app_name = "app";
    }

    char *port = "8080";
    if (argc >= 4 + arg_offset) {
        port = argv[3 + arg_offset];
    }

    printf("Starting nibiru with %d workers\n", num_workers);

    int status;

    // Preflight validation - create a temporary worker to validate the
    // application
    struct WorkerState preflight_worker;
    status = initialize_worker(&preflight_worker, app_module, app_name);
    if (status != 0) {
        free_worker(&preflight_worker);
        return 1;
    }
    free_worker(&preflight_worker); // Clean up preflight worker

    // Set up signal handlers for graceful shutdown
    struct sigaction sa;
    sa.sa_handler = signal_handler;
    sa.sa_flags = 0;
    sigemptyset(&sa.sa_mask);

    // Handle SIGTERM and SIGINT for graceful shutdown
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);

    // Ignore SIGPIPE (broken pipe from client disconnects)
    sa.sa_handler = SIG_IGN;
    sigaction(SIGPIPE, &sa, NULL);

    // Set up the listening socket
    struct addrinfo hints;
    struct addrinfo *server_info;

    memset(&hints, 0, sizeof(hints));
    hints.ai_flags = AI_PASSIVE;
    hints.ai_family = AF_UNSPEC; // IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM;

    int addr_status = getaddrinfo(NULL, port, &hints, &server_info);
    if (addr_status != 0) {
        fprintf(stderr, "Failed to get server information: %s\n",
                gai_strerror(addr_status));
        return 1;
    }

    struct addrinfo *current_server_info;
    int listen_socket_fd;
    for (current_server_info = server_info; current_server_info != NULL;
         current_server_info = current_server_info->ai_next) {
        listen_socket_fd = socket(current_server_info->ai_family,
                                  current_server_info->ai_socktype,
                                  current_server_info->ai_protocol);
        if (listen_socket_fd == -1) {
            continue;
        }

        int opt = 1;
        setsockopt(listen_socket_fd, SOL_SOCKET, SO_REUSEADDR, &opt,
                   sizeof(opt));

        int bind_status = bind(listen_socket_fd, current_server_info->ai_addr,
                               current_server_info->ai_addrlen);
        if (bind_status == -1) {
            close(listen_socket_fd);
            continue;
        }

        break;
    }

    freeaddrinfo(server_info);

    if (current_server_info == NULL) {
        perror("Failed to bind socket");
        return 1;
    }

    int backlog = 128;
    int listen_status = listen(listen_socket_fd, backlog);
    if (listen_status == -1) {
        perror("Failed to listen");
        close(listen_socket_fd);
        return 1;
    }

    printf("Server listening on %s...\n", port);

    // Create delegation socket for static files
    int delegation_socket = create_delegation_socket();
    if (delegation_socket == -1) {
        perror("Failed to create delegation socket");
        close(listen_socket_fd);
        return 1;
    }

    // Fork static worker
    pid_t static_pid = fork();
    if (static_pid == 0) {
        // Static worker
        close(listen_socket_fd); // Not needed
        run_static_event_loop(delegation_socket, static_dir, static_url);
        exit(0);
    } else if (static_pid == -1) {
        perror("Failed to fork static worker");
        close(listen_socket_fd);
        close(delegation_socket);
        return 1;
    }

    // Initialize the worker pool
    struct WorkerPool worker_pool;
    status = initialize_worker_pool(&worker_pool, num_workers);
    if (status != 0) {
        printf("Failed to initialize worker pool\n");
        free_worker_pool(&worker_pool);
        return 1;
    }

    pid_t main_pid = getpid();
    // Fork worker processes
    for (int i = 0; i < num_workers; i++) {
        pid_t pid = fork();
        if (pid == -1) {
            perror("Failed to fork worker");
            close(listen_socket_fd);
            free_worker_pool(&worker_pool);
            return 1;
        }
        if (pid == 0) {
            // Child process - become a worker
            return run_worker(i, listen_socket_fd, main_pid, app_module,
                              app_name);
        } else {
            // Parent process - record worker PID
            worker_pool.worker_pids[i] = pid;
        }
    }

    // Main server loop - wait for shutdown signal
    while (!shutdown_requested) {
        pause();
    }

    close(listen_socket_fd);
    free_worker_pool(&worker_pool);
    return 0;
}
