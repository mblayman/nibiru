// parse.h - HTTP request parsing functions

#ifndef PARSE_H
#define PARSE_H

#include <stddef.h>

// Supported HTTP methods
extern const char *SUPPORTED_METHODS[];
extern const int NUM_SUPPORTED_METHODS;

// Supported HTTP versions
extern const char *SUPPORTED_VERSIONS[];
extern const int NUM_SUPPORTED_VERSIONS;

// Check if method is supported (method may not be null-terminated)
int is_supported_method(const char *method, int method_len);

// Check if version is supported (version may not be null-terminated)
int is_supported_version(const char *version, int version_len);

// Parse HTTP request line from buffer
// Returns: 0 on success, -1 on parse error, -2 on validation error
// method, target, version point to positions in the original buffer
int parse_request_line(const char *buffer, int buffer_len, const char **method,
                       const char **target, const char **version,
                       int *method_len, int *target_len, int *version_len);

#endif // PARSE_H