#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define WORKERS 4

void worker_process(int fd);

int main() {
    int listen_fd, conn_fd;
    int unix_fds[WORKERS][2];
    struct sockaddr_in serv_addr;

    // Create listening socket
    listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    serv_addr.sin_port = htons(8080);

    bind(listen_fd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
    listen(listen_fd, 10);

    // Create UNIX domain socket pairs
    for (int i = 0; i < WORKERS; i++) {
        socketpair(AF_UNIX, SOCK_STREAM, 0, unix_fds[i]);
    }

    // Fork worker processes
    for (int i = 0; i < WORKERS; i++) {
        if (fork() == 0) {
            // Close the parent's side of the socketpair in the child
            close(unix_fds[i][0]);
            worker_process(unix_fds[i][1]);
            exit(0);
        }
        // Close the child's side of the socketpair in the parent
        close(unix_fds[i][1]);
    }

    // Main process handles incoming connections and passes them to workers
    int current_worker = 0;
    while (1) {
        conn_fd = accept(listen_fd, (struct sockaddr*)NULL, NULL);

        // Pass the accepted socket file descriptor to a worker
        struct msghdr msg = {0};
        struct cmsghdr *cmsg;
        char buf[CMSG_SPACE(sizeof(conn_fd))];
        memset(buf, 0, sizeof(buf));

        struct iovec io = { .iov_base = "FD", .iov_len = 2 };
        msg.msg_iov = &io;
        msg.msg_iovlen = 1;

        msg.msg_control = buf;
        msg.msg_controllen = sizeof(buf);

        cmsg = CMSG_FIRSTHDR(&msg);
        cmsg->cmsg_level = SOL_SOCKET;
        cmsg->cmsg_type = SCM_RIGHTS;
        cmsg->cmsg_len = CMSG_LEN(sizeof(conn_fd));

        memcpy(CMSG_DATA(cmsg), &conn_fd, sizeof(conn_fd));

        // Send the file descriptor to the current worker
        if (sendmsg(unix_fds[current_worker][0], &msg, 0) == -1) {
            perror("sendmsg");
        }
        close(conn_fd);

        // Move to the next worker
        current_worker = (current_worker + 1) % WORKERS;
    }

    close(listen_fd);
    return 0;
}

void worker_process(int fd) {
    while (1) {
        struct msghdr msg = {0};
        struct cmsghdr *cmsg;
        char buf[CMSG_SPACE(sizeof(int))];
        char iobuf[2];
        struct iovec io = { .iov_base = iobuf, .iov_len = sizeof(iobuf) };

        msg.msg_iov = &io;
        msg.msg_iovlen = 1;
        msg.msg_control = buf;
        msg.msg_controllen = sizeof(buf);

        if (recvmsg(fd, &msg, 0) == -1) {
            perror("recvmsg");
            continue;
        }

        cmsg = CMSG_FIRSTHDR(&msg);
        int conn_fd;
        memcpy(&conn_fd, CMSG_DATA(cmsg), sizeof(conn_fd));

        // Handle the connection
        // For example, send a simple response
        char *response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, World!";
        write(conn_fd, response, strlen(response));
        close(conn_fd);
    }
}
