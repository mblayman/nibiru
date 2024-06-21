#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

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
        printf("accepted a connection\n");

        close(accepted_socket_fd);
    }

    close(listen_socket_fd);

    return 0;
}
