#include <bsd/string.h> // for strlcpy on some systems
#include <errno.h>
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
#include <sys/wait.h>
#include <unistd.h>

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

// Signal handler for graceful shutdown
void signal_handler(int signum) { shutdown_requested = 1; }

// Forward declarations
int send_completion_to_parent(int unix_socket);
int receive_completion_from_worker(int unix_socket);
int send_fd_to_worker(int unix_socket, int fd_to_send);
int receive_fd_from_parent(int unix_socket);

struct WorkerPool {
    int num_workers;
    pid_t worker_pids[MAX_WORKERS];
    int fd_sockets[MAX_WORKERS];         // For sending FDs to workers
    int completion_sockets[MAX_WORKERS]; // For receiving completion
                                         // notifications from workers
    int connection_counts[MAX_WORKERS];  // For least connection load balancing
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

int run_worker(int worker_id, int fd_socket, int completion_socket,
               const char *app_module, const char *app_name) {
    // Initialize worker state
    struct WorkerState worker;
    int status = initialize_worker(&worker, app_module, app_name);
    if (status != 0) {
        free_worker(&worker);
        return 1;
    }

    printf("Worker %d started with PID %d\n", worker_id, getpid());

    // Worker main loop - receive FDs and handle connections
    while (1) {
        // Receive file descriptor from parent
        int client_fd = receive_fd_from_parent(fd_socket);
        if (client_fd == -2) {
            // Parent closed the socket - exit gracefully
            printf("Worker %d: Parent exited, shutting down\n", worker_id);
            break;
        }
        if (client_fd == -2) {
            // Parent closed the socket - exit gracefully
            printf("Worker %d: Parent exited, shutting down\n", worker_id);
            break;
        }
        if (client_fd == -1) {
            fprintf(stderr, "Worker %d: Failed to receive FD (errno=%d)\n",
                    worker_id, errno);
            // Small delay to prevent busy looping on persistent errors
            usleep(10000);
            continue;
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

            // Process the request with Lua
            lua_rawgeti(worker.lua_state, LUA_REGISTRYINDEX,
                        worker.handle_connection_reference);
            lua_rawgeti(worker.lua_state, LUA_REGISTRYINDEX,
                        worker.application_reference);
            lua_pushstring(worker.lua_state, receive_buffer);

            status = lua_pcall(worker.lua_state, 2, 1, 0);
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
            printf("Worker %d: Connection closed by client\n", worker_id);
        } else {
            perror("Worker: recv failed");
        }

        close(client_fd);

        // Send completion notification back to parent
        if (send_completion_to_parent(completion_socket) != 0) {
            fprintf(stderr,
                    "Worker %d: Failed to send completion notification\n",
                    worker_id);
        }
    }

    free_worker(&worker);
    return 0;
}

int initialize_worker_pool(struct WorkerPool *pool, int num_workers,
                           const char *app_module, const char *app_name) {
    pool->num_workers = num_workers;

    // Initialize arrays
    for (int i = 0; i < num_workers; i++) {
        pool->worker_pids[i] = -1;
        pool->fd_sockets[i] = -1;
        pool->completion_sockets[i] = -1;
        pool->connection_counts[i] = 0;
    }

    // Create socket pairs for each worker (two pairs: one for FDs, one for
    // completion)
    for (int i = 0; i < num_workers; i++) {
        // FD passing socket pair
        int fd_sockets[2];
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, fd_sockets) == -1) {
            perror("Failed to create FD socket pair");
            return 1;
        }

        // Completion notification socket pair
        int completion_sockets[2];
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, completion_sockets) == -1) {
            perror("Failed to create completion socket pair");
            close(fd_sockets[0]);
            close(fd_sockets[1]);
            return 1;
        }

        pool->fd_sockets[i] = fd_sockets[0]; // Parent sends FDs
        pool->completion_sockets[i] =
            completion_sockets[0]; // Parent receives completions

        // Fork worker process
        pid_t pid = fork();
        if (pid == -1) {
            perror("Failed to fork worker");
            close(fd_sockets[0]);
            close(fd_sockets[1]);
            close(completion_sockets[0]);
            close(completion_sockets[1]);
            return 1;
        }

        if (pid == 0) {
            // Child process - become a worker
            close(fd_sockets[0]);         // Close parent's FD socket
            close(completion_sockets[0]); // Close parent's completion socket
            return run_worker(i, fd_sockets[1], completion_sockets[1],
                              app_module, app_name);
        } else {
            // Parent process
            pool->worker_pids[i] = pid;
            close(fd_sockets[1]);         // Close worker's FD socket
            close(completion_sockets[1]); // Close worker's completion socket
        }
    }

    return 0;
}

void free_worker_pool(struct WorkerPool *pool) {
    for (int i = 0; i < pool->num_workers; i++) {
        if (pool->worker_pids[i] != -1) {
            kill(pool->worker_pids[i], SIGTERM);
        }
        if (pool->fd_sockets[i] != -1) {
            close(pool->fd_sockets[i]);
        }
        if (pool->completion_sockets[i] != -1) {
            close(pool->completion_sockets[i]);
        }
    }
}

// Find worker with least connections (least connection load balancing)
int find_least_loaded_worker(struct WorkerPool *pool) {
    int min_connections = INT_MAX;
    int selected_worker = 0;

    for (int i = 0; i < pool->num_workers; i++) {
        if (pool->connection_counts[i] < min_connections) {
            min_connections = pool->connection_counts[i];
            selected_worker = i;
        }
    }

    return selected_worker;
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

// Send a file descriptor to a worker via UNIX socket
int send_fd_to_worker(int unix_socket, int fd_to_send) {
    struct msghdr msg = {0};
    struct cmsghdr *cmsg;
    char buf[CMSG_SPACE(sizeof(fd_to_send))];
    memset(buf, 0, sizeof(buf));

    // Dummy data to send
    struct iovec io = {.iov_base = "FD", .iov_len = 2};
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;

    msg.msg_control = buf;
    msg.msg_controllen = sizeof(buf);

    cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(fd_to_send));

    memcpy(CMSG_DATA(cmsg), &fd_to_send, sizeof(fd_to_send));

    ssize_t sent = sendmsg(unix_socket, &msg, 0);
    if (sent == -1) {
        perror("sendmsg failed");
        return -1;
    }

    return 0;
}

// Receive a file descriptor from the parent
int receive_fd_from_parent(int unix_socket) {
    struct msghdr msg = {0};
    struct cmsghdr *cmsg;
    char buf[CMSG_SPACE(sizeof(int))];
    char iobuf[2];

    struct iovec io = {.iov_base = iobuf, .iov_len = sizeof(iobuf)};
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;
    msg.msg_control = buf;
    msg.msg_controllen = sizeof(buf);

    ssize_t received = recvmsg(unix_socket, &msg, 0);
    if (received == -1) {
        perror("recvmsg failed");
        return -1;
    }
    if (received == 0) {
        // Parent closed the socket - exit gracefully
        printf("Worker: Parent closed connection, exiting\n");
        return -2; // Special value to indicate parent exit
    }

    cmsg = CMSG_FIRSTHDR(&msg);
    if (cmsg == NULL || cmsg->cmsg_level != SOL_SOCKET ||
        cmsg->cmsg_type != SCM_RIGHTS) {
        fprintf(stderr, "Invalid control message\n");
        return -1;
    }

    cmsg = CMSG_FIRSTHDR(&msg);
    if (cmsg == NULL) {
        fprintf(stderr, "No control message received\n");
        return -1;
    }
    if (cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS) {
        fprintf(stderr, "Invalid control message: level=%d, type=%d\n",
                cmsg->cmsg_level, cmsg->cmsg_type);
        return -1;
    }

    int received_fd;
    memcpy(&received_fd, CMSG_DATA(cmsg), sizeof(received_fd));
    return received_fd;
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
        printf("Usage: nibiru run [--workers N] <app> [port]\n");
        printf("  <app> is in format of: module.path:app\n");
        printf("  --workers N: number of worker processes (default: 2)\n");
        return 1;
    }

    if (strcmp(argv[1], "run") != 0) {
        printf("Unknown subcommand: %s\n", argv[1]);
        printf("Usage: nibiru run [--workers N] <app> [port]\n");
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
            printf("Usage: nibiru run [--workers N] <app> [port]\n");
            return 1;
        }
        arg_offset = 1;
    } else if (argc >= 4 && strcmp(argv[2], "--workers") == 0) {
        // Parse --workers N format
        char *endptr;
        num_workers = strtol(argv[3], &endptr, 10);
        if (*endptr != '\0' || num_workers <= 0) {
            printf("Error: --workers must be a positive integer\n");
            printf("Usage: nibiru run [--workers N] <app> [port]\n");
            return 1;
        }
        arg_offset = 2;
    }

    if (argc < 3 + arg_offset) {
        printf("Usage: nibiru run [--workers N] <app> [port]\n");
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

    printf("Starting nibiru with %d worker(s)\n", num_workers);

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

    // Initialize the worker pool
    struct WorkerPool worker_pool;
    status =
        initialize_worker_pool(&worker_pool, num_workers, app_module, app_name);
    if (status != 0) {
        printf("Failed to initialize worker pool\n");
        free_worker_pool(&worker_pool);
        return 1;
    }

    // Worker pool initialized successfully
    printf("Worker pool initialized with %d workers\n",
           worker_pool.num_workers);

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
        free_worker_pool(&worker_pool);
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
        free_worker_pool(&worker_pool);
        return 1;
    }

    int backlog = 128;
    int listen_status = listen(listen_socket_fd, backlog);
    if (listen_status == -1) {
        perror("Failed to listen");
        close(listen_socket_fd);
        free_worker_pool(&worker_pool);
        return 1;
    }

    printf("Server listening on %s with %d workers...\n", port,
           worker_pool.num_workers);

    // Main server loop - accept connections and handle worker communications
    while (!shutdown_requested) {
        // Check for completion notifications from all workers
        for (int i = 0; i < worker_pool.num_workers; i++) {
            int completion = receive_completion_from_worker(
                worker_pool.completion_sockets[i]);
            if (completion == 1) {
                // Worker completed a connection
                worker_pool.connection_counts[i]--;
            } else if (completion == -1) {
                // Worker socket closed - worker may have died
                fprintf(stderr, "Worker %d socket closed unexpectedly\n", i);
            }
        }

        // Accept new connections
        struct sockaddr_storage client_addr;
        socklen_t addr_size = sizeof(client_addr);

        int client_fd = accept(listen_socket_fd,
                               (struct sockaddr *)&client_addr, &addr_size);
        if (client_fd == -1) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                // No connection available, continue checking worker messages
                usleep(1000); // Small delay to avoid busy waiting
                continue;
            }
            perror("Accept failed");
            continue;
        }

        // Select worker with least connections
        int selected_worker = find_least_loaded_worker(&worker_pool);
        // Connection routed to worker

        // Send FD to the selected worker
        int send_status = send_fd_to_worker(
            worker_pool.fd_sockets[selected_worker], client_fd);
        if (send_status != 0) {
            fprintf(stderr, "Failed to send FD to worker %d\n",
                    selected_worker);
            close(client_fd);
        } else {
            // Track connection count for load balancing
            worker_pool.connection_counts[selected_worker]++;
            // Connection tracked
        }

        // Close our copy of the client FD (worker has it now)
        close(client_fd);
    }

    close(listen_socket_fd);
    free_worker_pool(&worker_pool);
    return 0;
}