// test_parse.c - Unit tests for HTTP parsing functions

#include "../src/parse.h"
#include "unity.h"
#include <string.h>

// Test fixtures
void setUp(void) {
    // Setup code if needed
}

void tearDown(void) {
    // Cleanup code if needed
}

// Test is_supported_method function
void test_is_supported_method_valid(void) {
    TEST_ASSERT_TRUE(is_supported_method("GET", 3));
    TEST_ASSERT_TRUE(is_supported_method("POST", 4));
    TEST_ASSERT_TRUE(is_supported_method("PUT", 3));
    TEST_ASSERT_TRUE(is_supported_method("DELETE", 6));
    TEST_ASSERT_TRUE(is_supported_method("HEAD", 4));
    TEST_ASSERT_TRUE(is_supported_method("OPTIONS", 7));
    TEST_ASSERT_TRUE(is_supported_method("TRACE", 5));
    TEST_ASSERT_TRUE(is_supported_method("CONNECT", 7));
    TEST_ASSERT_TRUE(is_supported_method("PATCH", 5));
}

void test_is_supported_method_invalid(void) {
    TEST_ASSERT_FALSE(is_supported_method("INVALID", 7));
    TEST_ASSERT_FALSE(is_supported_method("get", 3));  // Wrong case
    TEST_ASSERT_FALSE(is_supported_method("GETS", 4)); // Wrong length
    TEST_ASSERT_FALSE(is_supported_method("", 0));     // Empty
}

void test_is_supported_method_edge_cases(void) {
    TEST_ASSERT_FALSE(is_supported_method(NULL, 0));   // Null pointer
    TEST_ASSERT_FALSE(is_supported_method("GET", 0));  // Zero length
    TEST_ASSERT_FALSE(is_supported_method("GET", 10)); // Length too long
}

// Test is_supported_version function
void test_is_supported_version_valid(void) {
    TEST_ASSERT_TRUE(is_supported_version("HTTP/1.1", 8));
}

void test_is_supported_version_invalid(void) {
    TEST_ASSERT_FALSE(is_supported_version("HTTP/1.0", 8));
    TEST_ASSERT_FALSE(is_supported_version("HTTP/2.0", 8));
    TEST_ASSERT_FALSE(is_supported_version("http/1.1", 8)); // Wrong case
    TEST_ASSERT_FALSE(is_supported_version("", 0));         // Empty
    TEST_ASSERT_FALSE(is_supported_version("HTTP/1.1", 5)); // Wrong length
}

// Test parse_request_line function
void test_parse_request_line_valid_get(void) {
    const char *buffer = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
    int buffer_len = 35; // Explicit length

    const char *method, *target, *version;
    int ml, tl, vl;

    int result = parse_request_line(buffer, buffer_len, &method, &target,
                                    &version, &ml, &tl, &vl);

    TEST_ASSERT_EQUAL(0, result);
    TEST_ASSERT_EQUAL_STRING_LEN("GET", method, ml);
    TEST_ASSERT_EQUAL_STRING_LEN("/", target, tl);
    TEST_ASSERT_EQUAL_STRING_LEN("HTTP/1.1", version, vl);
}

void test_parse_request_line_valid_post(void) {
    const char *buffer = "POST /api HTTP/1.1\r\nContent-Length: 0\r\n\r\n";
    const char *method, *target, *version;
    int ml, tl, vl;

    int result = parse_request_line(buffer, strlen(buffer), &method, &target,
                                    &version, &ml, &tl, &vl);

    TEST_ASSERT_EQUAL(0, result);
    TEST_ASSERT_EQUAL_STRING_LEN("POST", method, ml);
    TEST_ASSERT_EQUAL_STRING_LEN("/api", target, tl);
    TEST_ASSERT_EQUAL_STRING_LEN("HTTP/1.1", version, vl);
}

void test_parse_request_line_invalid_method(void) {
    const char *buffer = "INVALID / HTTP/1.1\r\n\r\n";
    const char *method, *target, *version;
    int ml, tl, vl;

    int result = parse_request_line(buffer, strlen(buffer), &method, &target,
                                    &version, &ml, &tl, &vl);

    TEST_ASSERT_EQUAL(-2, result); // Validation error
}

void test_parse_request_line_invalid_version(void) {
    const char *buffer = "GET / HTTP/2.0\r\n\r\n";
    const char *method, *target, *version;
    int ml, tl, vl;

    int result = parse_request_line(buffer, strlen(buffer), &method, &target,
                                    &version, &ml, &tl, &vl);

    TEST_ASSERT_EQUAL(-2, result); // Validation error
}

void test_parse_request_line_malformed(void) {
    // Missing CRLF
    const char *buffer1 = "GET / HTTP/1.1";
    const char *method, *target, *version;
    int ml, tl, vl;

    int result1 = parse_request_line(buffer1, strlen(buffer1), &method, &target,
                                     &version, &ml, &tl, &vl);
    TEST_ASSERT_EQUAL(-1, result1); // Parse error

    // Empty request line
    const char *buffer2 = "\r\n";
    int result2 = parse_request_line(buffer2, strlen(buffer2), &method, &target,
                                     &version, &ml, &tl, &vl);
    TEST_ASSERT_EQUAL(-1, result2); // Parse error

    // Leading whitespace
    const char *buffer3 = " GET / HTTP/1.1\r\n\r\n";
    int result3 = parse_request_line(buffer3, strlen(buffer3), &method, &target,
                                     &version, &ml, &tl, &vl);
    TEST_ASSERT_EQUAL(-3, result3); // Parse error: leading whitespace
}

void test_parse_request_line_edge_cases(void) {
    // Missing target (spaces but no target)
    const char *buffer1 = "GET  HTTP/1.1\r\n\r\n";
    const char *method, *target, *version;
    int ml, tl, vl;

    int result1 = parse_request_line(buffer1, strlen(buffer1), &method, &target,
                                     &version, &ml, &tl, &vl);
    TEST_ASSERT_EQUAL(-7, result1); // Parse error: no version

    // Missing version
    const char *buffer2 = "GET /\r\n\r\n";
    int result2 = parse_request_line(buffer2, strlen(buffer2), &method, &target,
                                     &version, &ml, &tl, &vl);
    TEST_ASSERT_EQUAL(-7, result2); // Parse error: no version

    // Extra spaces
    const char *buffer3 = "GET   /   HTTP/1.1\r\n\r\n";
    int result3 = parse_request_line(buffer3, strlen(buffer3), &method, &target,
                                     &version, &ml, &tl, &vl);
    TEST_ASSERT_EQUAL(0, result3); // Should succeed
    TEST_ASSERT_EQUAL_STRING_LEN("GET", method, ml);
    TEST_ASSERT_EQUAL_STRING_LEN("/", target, tl);
    TEST_ASSERT_EQUAL_STRING_LEN("HTTP/1.1", version, vl);
}

void test_parse_request_line_complex_target(void) {
    const char *buffer = "GET /api/v1/users?query=test HTTP/1.1\r\n\r\n";
    const char *method, *target, *version;
    int ml, tl, vl;

    int result = parse_request_line(buffer, strlen(buffer), &method, &target,
                                    &version, &ml, &tl, &vl);

    TEST_ASSERT_EQUAL(0, result);
    TEST_ASSERT_EQUAL_STRING_LEN("GET", method, ml);
    TEST_ASSERT_EQUAL_STRING_LEN("/api/v1/users?query=test", target, tl);
    TEST_ASSERT_EQUAL_STRING_LEN("HTTP/1.1", version, vl);
}