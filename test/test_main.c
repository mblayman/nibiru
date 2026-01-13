// test_main.c - Unity test runner main

#include "../src/static.h"
#include "unity.h"

// Declarations for internal static functions
const char *get_mime_type(const char *path);
int sanitize_path(const char *path, char *out, size_t out_size,
                  const char *static_dir, const char *static_url);
int serialize_request(char *buf, size_t buf_size, const char *method,
                      const char *path, int client_fd);
int deserialize_request(const char *buf, size_t buf_size, char *method,
                        size_t method_size, char *path, size_t path_size,
                        int *client_fd);

// Test functions declared in test_parse.c
void test_is_supported_method_valid(void);
void test_is_supported_method_invalid(void);
void test_is_supported_method_edge_cases(void);
void test_is_supported_version_valid(void);
void test_is_supported_version_invalid(void);
void test_parse_request_line_valid_get(void);
void test_parse_request_line_valid_post(void);
void test_parse_request_line_invalid_method(void);
void test_parse_request_line_invalid_version(void);
void test_parse_request_line_malformed(void);
void test_parse_request_line_edge_cases(void);
void test_parse_request_line_complex_target(void);

// Static file tests
void test_is_static_request_valid(void);
void test_is_static_request_invalid(void);
void test_get_mime_type_known(void);
void test_get_mime_type_unknown(void);
void test_sanitize_path_valid(void);
void test_sanitize_path_traversal(void);
void test_sanitize_path_invalid_url(void);

// Static file test implementations
void test_is_static_request_valid(void) {
    TEST_ASSERT_TRUE(is_static_request("/static/file.txt", "/static"));
    TEST_ASSERT_TRUE(is_static_request("/static/", "/static"));
    TEST_ASSERT_TRUE(is_static_request("/static", "/static"));
}

void test_is_static_request_invalid(void) {
    TEST_ASSERT_FALSE(is_static_request("/other/file.txt", "/static"));
    TEST_ASSERT_FALSE(is_static_request("/static", "/other"));
    TEST_ASSERT_FALSE(is_static_request("/", "/static"));
}

void test_get_mime_type_known(void) {
    TEST_ASSERT_EQUAL_STRING("text/html", get_mime_type("test.html"));
    TEST_ASSERT_EQUAL_STRING("text/plain", get_mime_type("test.txt"));
    TEST_ASSERT_EQUAL_STRING("image/png", get_mime_type("test.png"));
}

void test_get_mime_type_unknown(void) {
    TEST_ASSERT_EQUAL_STRING("application/octet-stream",
                             get_mime_type("test.unknown"));
    TEST_ASSERT_EQUAL_STRING("application/octet-stream", get_mime_type("test"));
}

void test_sanitize_path_valid(void) {
    char out[PATH_MAX];
    int result = sanitize_path("/static/test.txt", out, sizeof(out),
                               "tests/data/static", "/static");
    TEST_ASSERT_EQUAL(0, result);
    TEST_ASSERT_EQUAL_STRING("tests/data/static/test.txt", out);
}

void test_sanitize_path_traversal(void) {
    char out[PATH_MAX];
    int result = sanitize_path("/static/../etc/passwd", out, sizeof(out),
                               "tests/data/static", "/static");
    TEST_ASSERT_EQUAL(-1, result);
}

void test_sanitize_path_invalid_url(void) {
    char out[PATH_MAX];
    int result = sanitize_path("/other/test.txt", out, sizeof(out),
                               "tests/data/static", "/static");
    TEST_ASSERT_EQUAL(-1, result);
}

void test_serialize_deserialize_request(void) {
    char buf[1024];
    const char *method = "GET";
    const char *path = "/static/test.txt";
    int client_fd = 42;

    int len = serialize_request(buf, sizeof(buf), method, path, client_fd);
    TEST_ASSERT_GREATER_THAN(0, len);

    char out_method[16];
    char out_path[PATH_MAX];
    int out_client_fd;
    int result =
        deserialize_request(buf, len, out_method, sizeof(out_method), out_path,
                            sizeof(out_path), &out_client_fd);
    TEST_ASSERT_EQUAL(0, result);
    TEST_ASSERT_EQUAL_STRING(method, out_method);
    TEST_ASSERT_EQUAL_STRING(path, out_path);
    TEST_ASSERT_EQUAL(client_fd, out_client_fd);
}

int main(void) {
    UNITY_BEGIN();

    // Run all parsing tests
    RUN_TEST(test_is_supported_method_valid);
    RUN_TEST(test_is_supported_method_invalid);
    RUN_TEST(test_is_supported_method_edge_cases);
    RUN_TEST(test_is_supported_version_valid);
    RUN_TEST(test_is_supported_version_invalid);
    RUN_TEST(test_parse_request_line_valid_get);
    RUN_TEST(test_parse_request_line_valid_post);
    RUN_TEST(test_parse_request_line_invalid_method);
    RUN_TEST(test_parse_request_line_invalid_version);
    RUN_TEST(test_parse_request_line_malformed);
    RUN_TEST(test_parse_request_line_edge_cases);
    RUN_TEST(test_parse_request_line_complex_target);

    // Run static file tests
    RUN_TEST(test_is_static_request_valid);
    RUN_TEST(test_is_static_request_invalid);
    RUN_TEST(test_get_mime_type_known);
    RUN_TEST(test_get_mime_type_unknown);
    RUN_TEST(test_sanitize_path_valid);
    RUN_TEST(test_sanitize_path_traversal);
    RUN_TEST(test_sanitize_path_invalid_url);
    RUN_TEST(test_serialize_deserialize_request);

    return UNITY_END();
}