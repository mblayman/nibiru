#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

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
        lua_close(lua_state);
        return -1;
    }

    int lua_type = lua_getfield(lua_state, -1, function_name);
    if (lua_type != LUA_TFUNCTION) {
        printf("Unexpected type: %s is not a function.", function_name);
        lua_close(lua_state);
        return -1;
    }

    int function_reference = luaL_ref(lua_state, LUA_REGISTRYINDEX);

    // Take the module off the stack to clean up.
    lua_pop(lua_state, 1);

    return function_reference;
}

int main(int argc, char *argv[]) {
    /*
     * Process arguments.
     */
    if (argc < 2) {
        printf("Expected app callable in format of: module.path:app\n");
        return 1;
    }

    char *app_specifier = argv[1];
    char *app_module = strsep(&app_specifier, ":");
    char *app_name = strsep(&app_specifier, ":");
    // The default callable name is "app".
    if (app_name == NULL) {
        app_name = "app";
    }

    int status;

    /*
     * Initialize Lua.
     */
    lua_State *lua_state = luaL_newstate();
    luaL_openlibs(lua_state);

    // Load the bootstrap module to get the WSGI callable.
    int bootstrap_reference = nibiru_load_registered_lua_function(
        lua_state, "nibiru.boot", "bootstrap");
    if (bootstrap_reference == -1) {
        return 1;
    }

    lua_rawgeti(lua_state, LUA_REGISTRYINDEX, bootstrap_reference);
    lua_pushstring(lua_state, app_module);
    lua_pushstring(lua_state, app_name);
    status = lua_pcall(lua_state, 2, 1, 0);
    if (status != LUA_OK) {
        printf("Error: %s\n", lua_tostring(lua_state, -1));
        lua_close(lua_state);
        return 1;
    }
    status = lua_isfunction(lua_state, -1);
    if (status == 0) {
        printf("`%s` is not a valid function.\n", app_name);
        lua_close(lua_state);
        return 1;
    }
    int application_reference = luaL_ref(lua_state, LUA_REGISTRYINDEX);

    // Load the connection handler.
    int handle_connection_reference = nibiru_load_registered_lua_function(
        lua_state, "nibiru.connector", "handle_connection");
    if (handle_connection_reference == -1) {
        return 1;
    }

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

    // TODO: Listening port should be be configurable and not locked to 8080.
    status = getaddrinfo(NULL, "8080", &hints, &server_info);
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

        // TODO: setsockopt for SO_REUSEADDR. This may be needed if hitting the
        // TIME_WAIT state. It introduces some data risk.
        // https://stackoverflow.com/a/3233022 covers this well.

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

    int backlog = 32; // `man 2 listen` says max is 128.
    status = listen(listen_socket_fd, backlog);
    if (status == -1) {
        close(listen_socket_fd);
        perror("nibiru error");
        exit(1);
    }

    // TODO: make this message a format string.
    printf("Listening on 8080...\n");

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
            receive_buffer[bytes_received] = '\0';
        } else {
            // TODO: 0 is closed connection, -1 is error. Handle those.
        }

        // Add handle_connection back to the Lua stack.
        lua_rawgeti(lua_state, LUA_REGISTRYINDEX, handle_connection_reference);

        lua_rawgeti(lua_state, LUA_REGISTRYINDEX, application_reference);
        lua_pushstring(lua_state, receive_buffer);

        status = lua_pcall(lua_state, 2, 1, 0);
        if (status != LUA_OK) {
            printf("Error: %s\n", lua_tostring(lua_state, -1));
            lua_close(lua_state);
            return 1;
        }

        size_t response_length;
        const char *response = lua_tolstring(lua_state, -1, &response_length);

        // printf("%s\n", response);
        // printf("%zu\n", response_length);
        int bytes_sent = send(accepted_socket_fd, response, response_length, 0);
        if (bytes_sent == -1) {
            // TODO: handle error
        }

        // Only pop after C has the chance to do something. If popped early,
        // there is a chance that the Lua GC kicks in and frees the memory.
        lua_pop(lua_state, 1);

        close(accepted_socket_fd);
    }

    close(listen_socket_fd);
    lua_close(lua_state);

    return 0;
}
