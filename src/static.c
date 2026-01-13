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
                      size_t method_len, const char *path, size_t path_len,
                      int client_fd) {
    // Format: method\0path\0client_fd
    size_t total = method_len + 1 + path_len + 1 + sizeof(int);
    if (total > buf_size)
        return -1;

    memcpy(buf, method, method_len);
    buf[method_len] = '\0';
    memcpy(buf + method_len + 1, path, path_len);
    buf[method_len + 1 + path_len] = '\0';
    memcpy(buf + method_len + 1 + path_len + 1, &client_fd, sizeof(int));
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
                            size_t method_len, const char *path,
                            size_t path_len, int client_fd) {
    char buf[1024];
    int len = serialize_request(buf, sizeof(buf), method, method_len, path,
                                path_len, client_fd);
    if (len == -1) {
        return -1;
    }

    // Send data
    ssize_t sent = send(delegation_socket, buf, len, 0);
    if (sent == -1) {
        perror("send in delegate");
        return -1;
    }
    return 0;
}

// Receive delegated request
int receive_delegated_request(int delegation_socket, char *method,
                              size_t method_size, char *path,
                              size_t path_size) {
    char buf[1024];
    ssize_t received = recv(delegation_socket, buf, sizeof(buf), 0);
    if (received == -1) {
        perror("recv in receive");
        return -1;
    }
    int dummy_fd;
    int result = deserialize_request(buf, received, method, method_size, path,
                                     path_size, &dummy_fd);
    return result;
}

// Event loop for static worker
void run_static_event_loop(int delegation_socket, const char *static_dir,
                           const char *static_url) {
    while (1) {
        int delegation_client_fd = accept(delegation_socket, NULL, NULL);
        if (delegation_client_fd == -1) {
            if (errno == EINTR)
                continue;
            perror("accept in static worker");
            break;
        }
        char method[16];
        char path[PATH_MAX];
        if (receive_delegated_request(delegation_client_fd, method,
                                      sizeof(method), path,
                                      sizeof(path)) == 0) {
            serve_static_file(delegation_client_fd, path, static_dir,
                              static_url);
        }
        close(delegation_client_fd);
    }
}

// Placeholder for kqueue implementation
#ifdef USE_KQUEUE
// Implement kqueue version similarly
#endif

// Placeholder for kqueue implementation
