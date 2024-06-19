#include <netdb.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>

int main(void) {
    int status;
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
            // TODO: this should log, but it shouldn't be a prominent error
            // since the objective is to bind to any address in server_info.
            continue;
        }

        // TODO: setsockopt - why?

        // TODO: bind
    }

    freeaddrinfo(server_info);

    // TODO: check current_server_info == NULL means nothing bound.

    // TOOD: listen

    return 0;
}
