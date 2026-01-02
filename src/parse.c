// parse.c - HTTP request parsing implementations

#include "parse.h"
#include <string.h>

// Supported HTTP methods (same as Lua parser)
const char *SUPPORTED_METHODS[] = {"GET",     "HEAD",   "POST",
                                   "PUT",     "DELETE", "CONNECT",
                                   "OPTIONS", "TRACE",  "PATCH"};
const int NUM_SUPPORTED_METHODS = 9;

// Supported HTTP versions
const char *SUPPORTED_VERSIONS[] = {"HTTP/1.1"};
const int NUM_SUPPORTED_VERSIONS = 1;

// Check if method is supported (method may not be null-terminated)
int is_supported_method(const char *method, int method_len) {
    for (int i = 0; i < NUM_SUPPORTED_METHODS; i++) {
        const char *supported = SUPPORTED_METHODS[i];
        int supported_len = strlen(supported);
        if (method_len == supported_len &&
            strncmp(method, supported, method_len) == 0) {
            return 1;
        }
    }
    return 0;
}

// Check if version is supported (version may not be null-terminated)
int is_supported_version(const char *version, int version_len) {
    for (int i = 0; i < NUM_SUPPORTED_VERSIONS; i++) {
        const char *supported = SUPPORTED_VERSIONS[i];
        int supported_len = strlen(supported);
        if (version_len == supported_len &&
            strncmp(version, supported, version_len) == 0) {
            return 1;
        }
    }
    return 0;
}

// Parse HTTP request line from buffer
// Returns: 0 on success, negative codes for different errors
// -1: no CRLF, -2: validation error, -3: leading whitespace,
// -4: empty method, -5: no target, -6: empty target,
// -7: no version, -8: empty version, -9: invalid CRLF
int parse_request_line(const char *buffer, int buffer_len, const char **method,
                       const char **target, const char **version,
                       int *method_len, int *target_len, int *version_len) {
    // Find the end of the request line (\r\n) - HTTP spec requires CRLF
    const char *line_end = NULL;
    for (size_t i = 0; i < buffer_len - 1; i++) {
        if (buffer[i] == '\r' && buffer[i + 1] == '\n') {
            line_end = &buffer[i];
            break;
        }
    }
    if (!line_end || line_end == buffer) {
        return -1; // No \r\n found or empty line
    }

    // Parse the line manually to avoid copying
    const char *pos = buffer;
    const char *end = line_end;

    // HTTP spec requires method to start immediately (no leading whitespace)
    if (*pos == ' ')
        return -3; // Parse error: leading whitespace

    // Parse method
    *method = pos;
    while (pos < end && *pos != ' ')
        pos++;
    *method_len = pos - *method;
    if (*method_len == 0)
        return -4; // Parse error: empty method

    // Skip spaces after method
    while (pos < end && *pos == ' ')
        pos++;
    if (pos >= end)
        return -5; // Parse error: no target

    // Parse target
    *target = pos;
    while (pos < end && *pos != ' ')
        pos++;
    *target_len = pos - *target;
    if (*target_len == 0)
        return -6; // Parse error: empty target

    // Skip spaces after target
    while (pos < end && *pos == ' ')
        pos++;
    if (pos >= end)
        return -7; // Parse error: no version

    // Parse version (stops at \r)
    *version = pos;
    while (pos < end && *pos != '\r')
        pos++;
    *version_len = pos - *version;
    if (*version_len == 0)
        return -8; // Parse error: empty version

    // Verify CRLF follows immediately
    if (pos != end || *(pos + 1) != '\n')
        return -9; // Parse error: invalid CRLF

    // Validate method and version
    if (!is_supported_method(*method, *method_len))
        return -2; // Validation error: unsupported method
    if (!is_supported_version(*version, *version_len))
        return -2; // Validation error: unsupported version

    return 0; // Success
}