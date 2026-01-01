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
#include <unistd.h>

struct WorkerState {
    // The local Lua interpreter
    lua_State *lua_state;
    // The WSGI application callable
    int application_reference;
    // The connection handler within nibiru's Lua code
    int handle_connection_reference;
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

    // TODO: Use num_workers to create worker pool (nb-ar3)

    int status;

    // TODO: Rename to preflight after forking is actually working.
    // A preflight worker to validate that a valid application was specified.
    struct WorkerState worker;
    status = initialize_worker(&worker, app_module, app_name);
    if (status != 0) {
        free_worker(&worker);
        return 1;
    }

    /*
     * Initialize Lua.
     */
    // lua_State *lua_state = luaL_newstate();
    // luaL_openlibs(lua_state);
    //
    // // Load the bootstrap module to get the WSGI callable.
    // int bootstrap_reference = nibiru_load_registered_lua_function(
    //     lua_state, "nibiru.server.boot", "bootstrap");
    // if (bootstrap_reference == -1) {
    //     return 1;
    // }
    //
    // lua_rawgeti(lua_state, LUA_REGISTRYINDEX, bootstrap_reference);
    // lua_pushstring(lua_state, app_module);
    // lua_pushstring(lua_state, app_name);
    // status = lua_pcall(lua_state, 2, 1, 0);
    // if (status != LUA_OK) {
    //     printf("Error: %s\n", lua_tostring(lua_state, -1));
    //     lua_close(lua_state);
    //     return 1;
    // }
    // status = is_callable(lua_state);
    // if (status == 0) {
    //     printf("`%s` is not a valid callable.\n", app_name);
    //     lua_close(lua_state);
    //     return 1;
    // }
    // int application_reference = luaL_ref(lua_state, LUA_REGISTRYINDEX);
    //
    // // Load the connection handler.
    // int handle_connection_reference = nibiru_load_registered_lua_function(
    //     lua_state, "nibiru.server.connector", "handle_connection");
    // if (handle_connection_reference == -1) {
    //     return 1;
    // }

    /*
     * Start network connections.
     */
    struct addrinfo hints;
    struct addrinfo *server_info;

    memset(&hints, 0, sizeof(hints));
    // AI_PASSIVE because we're going to bind instead of using a hostname
    // for getaddrinfo.
    hints.ai_flags = AI_PASSIVE;
    hints.ai_family = AF_UNSPEC; // IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM;

    status = getaddrinfo(NULL, port, &hints, &server_info);
    if (status != 0) {
        fprintf(stderr, "Failed to get server information: %s\n",
                gai_strerror(status));
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

        // Allow reuse of addresses to avoid TIME_WAIT issues when restarting.
        int opt = 1;
        setsockopt(listen_socket_fd, SOL_SOCKET, SO_REUSEADDR, &opt,
                   sizeof(opt));

        status = bind(listen_socket_fd, current_server_info->ai_addr,
                      current_server_info->ai_addrlen);
        if (status == -1) {
            close(listen_socket_fd);
            continue;
        }

        break;
    }

    freeaddrinfo(server_info);

    if (current_server_info == NULL) {
        perror("nibiru error");
        exit(1);
    }

    int backlog = 128; // `man 2 listen` says max is 128.
    status = listen(listen_socket_fd, backlog);
    if (status == -1) {
        close(listen_socket_fd);
        perror("nibiru error");
        exit(1);
    }

    printf("Listening on %s...\n", port);

    // TODO: This should probably be much larger and configurable.
    int receive_buffer_size = 10000;
    char receive_buffer[receive_buffer_size];

    int accepted_socket_fd;
    struct sockaddr_storage accepted_socket_storage;
    socklen_t storage_size = sizeof(accepted_socket_storage);
    while (1) {
        accepted_socket_fd =
            accept(listen_socket_fd,
                   (struct sockaddr *)&accepted_socket_storage, &storage_size);
        if (accepted_socket_fd == -1) {
            perror("nibiru error");
            continue;
        }

        // TODO: This is serial for now. It would be easiest to do a forking
        // server, but I think that would be slow. Don't worry about this until
        // Lua is integrated.

        int bytes_received =
            recv(accepted_socket_fd, receive_buffer, receive_buffer_size, 0);
        if (bytes_received > 0) {
            // Add null to terminate the C string from Lua's point of view.
            // TODO: There is probably a bug here. If the bytes received is
            // exactly the same size as the buffer size, then setting at this
            // address will write outside of the buffer's actual memory.
            receive_buffer[bytes_received] = '\0';
        } else {
            // TODO: 0 is closed connection, -1 is error. Handle those.
        }

        // Add handle_connection back to the Lua stack.
        lua_rawgeti(worker.lua_state, LUA_REGISTRYINDEX,
                    worker.handle_connection_reference);

        lua_rawgeti(worker.lua_state, LUA_REGISTRYINDEX,
                    worker.application_reference);
        lua_pushstring(worker.lua_state, receive_buffer);

        status = lua_pcall(worker.lua_state, 2, 1, 0);
        if (status != LUA_OK) {
            printf("Error: %s\n", lua_tostring(worker.lua_state, -1));
            free_worker(&worker);
            return 1;
        }

        size_t response_length;
        const char *response =
            lua_tolstring(worker.lua_state, -1, &response_length);

        // printf("%s\n", response);
        // printf("%zu\n", response_length);
        int bytes_sent = send(accepted_socket_fd, response, response_length, 0);
        if (bytes_sent == -1) {
            // TODO: handle error
        }

        // Only pop after C has the chance to do something. If popped early,
        // there is a chance that the Lua GC kicks in and frees the memory.
        lua_pop(worker.lua_state, 1);

        close(accepted_socket_fd);
    }

    close(listen_socket_fd);
    free_worker(&worker);

    return 0;
}
