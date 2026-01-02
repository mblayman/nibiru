// test_main.c - Unity test runner main

#include "unity.h"

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

    return UNITY_END();
}