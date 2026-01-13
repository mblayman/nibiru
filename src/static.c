#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#ifdef __linux__
#include <sys/epoll.h>
#define USE_EPOLL 1
#elif defined(__APPLE__) || defined(__FreeBSD__)
#define USE_KQUEUE 1
#endif

// MIME type mapping - simple hardcoded list
typedef struct {
    const char *ext;
    const char *mime;
} mime_type;

static const mime_type mime_types[] = {
    {".html", "text/html"},        {".htm", "text/html"},
    {".css", "text/css"},          {".js", "application/javascript"},
    {".json", "application/json"}, {".png", "image/png"},
    {".jpg", "image/jpeg"},        {".jpeg", "image/jpeg"},
    {".gif", "image/gif"},         {".svg", "image/svg+xml"},
    {".ico", "image/x-icon"},      {".txt", "text/plain"},
    {".xml", "application/xml"},   {NULL, NULL}};

const char *get_mime_type(const char *path) {
    const char *ext = strrchr(path, '.');
    if (!ext)
        return "application/octet-stream";
    for (const mime_type *mt = mime_types; mt->ext; ++mt) {
        if (strcmp(ext, mt->ext) == 0) {
            return mt->mime;
        }
    }
    return "application/octet-stream";
}

// Check if path is a static request
int is_static_request(const char *path, const char *static_url) {
    if (!path || !static_url)
        return 0;
    size_t url_len = strlen(static_url);
    if (strncmp(path, static_url, url_len) == 0) {
        // Ensure it's followed by / or end
        return path[url_len] == '/' || path[url_len] == '\0';
    }
    return 0;
}

// Sanitize path to prevent directory traversal
int sanitize_path(const char *path, char *out, size_t out_size,
                  const char *static_dir, const char *static_url) {
    if (!path || !out || !static_dir || !static_url)
        return -1;

    // Skip the static_url prefix
    size_t url_len = strlen(static_url);
    if (strncmp(path, static_url, url_len) != 0)
        return -1;
    const char *file_path = path + url_len;

    // Check for .. in path
    if (strstr(file_path, ".."))
        return -1;

    // Construct full path
    if (snprintf(out, out_size, "%s%s", static_dir, file_path) >=
        (int)out_size) {
        return -1; // Path too long
    }

    return 0;
}

// Serve static file
int serve_static_file(int client_fd, const char *path, const char *static_dir,
                      const char *static_url) {
    char full_path[PATH_MAX];
    if (sanitize_path(path, full_path, sizeof(full_path), static_dir,
                      static_url) != 0) {
        // 404 for invalid paths
        const char *response = "HTTP/1.1 404 Not Found\r\nContent-Type: "
                               "text/plain\r\n\r\n404 Not Found";
        send(client_fd, response, strlen(response), 0);
        return 0;
    }

    struct stat st;
    if (stat(full_path, &st) != 0 || !S_ISREG(st.st_mode)) {
        // 404 for not found or not regular file
        const char *response = "HTTP/1.1 404 Not Found\r\nContent-Type: "
                               "text/plain\r\n\r\n404 Not Found";
        send(client_fd, response, strlen(response), 0);
        return 0;
    }

    int fd = open(full_path, O_RDONLY);
    if (fd == -1) {
        const char *response = "HTTP/1.1 404 Not Found\r\nContent-Type: "
                               "text/plain\r\n\r\n404 Not Found";
        send(client_fd, response, strlen(response), 0);
        return 0;
    }

    const char *mime = get_mime_type(full_path);
    char header[512];
    int header_len = snprintf(
        header, sizeof(header),
        "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %ld\r\n\r\n",
        mime, st.st_size);
    send(client_fd, header, header_len, 0);

    // Send file content
    char buf[8192];
    ssize_t n;
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        send(client_fd, buf, n, 0);
    }
    close(fd);
    return 0;
}

// Create Unix domain socket for delegation
int create_delegation_socket() {
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock == -1) {
        perror("socket");
        return -1;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof(addr.sun_path), "/tmp/nibiru_static_%d.sock",
             getpid());

    unlink(addr.sun_path); // Remove if exists
    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
        perror("bind");
        close(sock);
        return -1;
    }

    if (listen(sock, 10) == -1) {
        perror("listen");
        close(sock);
        return -1;
    }

    return sock;
}

// Serialize request for delegation
int serialize_request(char *buf, size_t buf_size, const char *method,
                      const char *path, int client_fd) {
    // Format: method\0path\0client_fd
    size_t method_len = strlen(method) + 1;
    size_t path_len = strlen(path) + 1;
    size_t total = method_len + path_len + sizeof(int);
    if (total > buf_size)
        return -1;

    memcpy(buf, method, method_len);
    memcpy(buf + method_len, path, path_len);
    memcpy(buf + method_len + path_len, &client_fd, sizeof(int));
    return total;
}

// Deserialize request
int deserialize_request(const char *buf, size_t buf_size, char *method,
                        size_t method_size, char *path, size_t path_size,
                        int *client_fd) {
    const char *p = buf;
    size_t len = strlen(p) + 1;
    if (len > method_size)
        return -1;
    strcpy(method, p);
    p += len;

    len = strlen(p) + 1;
    if (len > path_size)
        return -1;
    strcpy(path, p);
    p += len;

    if ((size_t)(p - buf) + sizeof(int) > buf_size)
        return -1;
    memcpy(client_fd, p, sizeof(int));
    return 0;
}

// Delegate static request
int delegate_static_request(int delegation_socket, const char *method,
                            const char *path, int client_fd) {
    char buf[1024];
    int len = serialize_request(buf, sizeof(buf), method, path, client_fd);
    if (len == -1)
        return -1;

    // Send data and fd
    struct msghdr msg = {0};
    struct cmsghdr *cmsg;
    char cbuf[CMSG_SPACE(sizeof(client_fd))];

    struct iovec io = {.iov_base = buf, .iov_len = len};
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;

    msg.msg_control = cbuf;
    msg.msg_controllen = sizeof(cbuf);

    cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(client_fd));
    memcpy(CMSG_DATA(cmsg), &client_fd, sizeof(client_fd));

    if (sendmsg(delegation_socket, &msg, 0) == -1) {
        perror("sendmsg");
        return -1;
    }
    return 0;
}

// Receive delegated request
int receive_delegated_request(int delegation_socket, char *method,
                              size_t method_size, char *path, size_t path_size,
                              int *client_fd) {
    char buf[1024];
    struct msghdr msg = {0};
    struct cmsghdr *cmsg;
    char cbuf[CMSG_SPACE(sizeof(int))];

    struct iovec io = {.iov_base = buf, .iov_len = sizeof(buf)};
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;
    msg.msg_control = cbuf;
    msg.msg_controllen = sizeof(cbuf);

    ssize_t received = recvmsg(delegation_socket, &msg, 0);
    if (received == -1) {
        perror("recvmsg");
        return -1;
    }

    cmsg = CMSG_FIRSTHDR(&msg);
    if (cmsg && cmsg->cmsg_level == SOL_SOCKET &&
        cmsg->cmsg_type == SCM_RIGHTS) {
        memcpy(client_fd, CMSG_DATA(cmsg), sizeof(int));
    } else {
        return -1;
    }

    return deserialize_request(buf, received, method, method_size, path,
                               path_size, client_fd);
}

// Event loop for static worker
void run_static_event_loop(int delegation_socket, const char *static_dir,
                           const char *static_url) {
#ifndef USE_EPOLL
    fprintf(stderr, "Static file serving is not supported on this platform "
                    "(requires Linux with epoll)\n");
    return;
#endif

#ifdef USE_EPOLL
    int epoll_fd = epoll_create1(0);
    if (epoll_fd == -1) {
        perror("epoll_create1");
        return;
    }

    struct epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.fd = delegation_socket;
    if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, delegation_socket, &ev) == -1) {
        perror("epoll_ctl");
        close(epoll_fd);
        return;
    }

    struct epoll_event events[10];
    while (1) {
        int nfds = epoll_wait(epoll_fd, events, 10, -1);
        if (nfds == -1) {
            if (errno == EINTR)
                continue;
            perror("epoll_wait");
            break;
        }

        for (int i = 0; i < nfds; ++i) {
            if (events[i].data.fd == delegation_socket) {
                char method[16];
                char path[PATH_MAX];
                int client_fd;
                if (receive_delegated_request(delegation_socket, method,
                                              sizeof(method), path,
                                              sizeof(path), &client_fd) == 0) {
                    serve_static_file(client_fd, path, static_dir, static_url);
                    close(client_fd);
                }
            }
        }
    }
    close(epoll_fd);
#endif
}

// Placeholder for kqueue implementation
