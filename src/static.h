#ifndef STATIC_H
#define STATIC_H

// Static file request detection
int is_static_request(const char *path, const char *static_url);

// Delegation of static requests
int delegate_static_request(int delegation_socket, const char *method,
                            const char *path, int client_fd);

// Socket creation for delegation
int create_delegation_socket();

// Event loop for static file serving
void run_static_event_loop(int delegation_socket, const char *static_dir,
                           const char *static_url);

#endif // STATIC_H