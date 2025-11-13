local assert = require("luassert")
local Template = require("nibiru.template")

local tests = {}

-- Built-in filter tests

function tests.test_uppercase_filter_basic()
    -- Test basic uppercase conversion
    local template = Template("{{ value |> uppercase }}")
    local result = template({ value = "hello world" })
    assert.equal("HELLO WORLD", result)
end

function tests.test_uppercase_filter_empty_string()
    -- Test uppercase with empty string
    local template = Template("{{ value |> uppercase }}")
    local result = template({ value = "" })
    assert.equal("", result)
end

function tests.test_uppercase_filter_mixed_case()
    -- Test uppercase with mixed case input
    local template = Template("{{ value |> uppercase }}")
    local result = template({ value = "HeLLo WoRlD" })
    assert.equal("HELLO WORLD", result)
end

function tests.test_uppercase_filter_numbers()
    -- Test uppercase with numbers (should pass through unchanged)
    local template = Template("{{ value |> uppercase }}")
    local result = template({ value = "hello123world" })
    assert.equal("HELLO123WORLD", result)
end

function tests.test_uppercase_filter_special_chars()
    -- Test uppercase with special characters
    local template = Template("{{ value |> uppercase }}")
    local result = template({ value = "hello-world_test@example.com" })
    assert.equal("HELLO-WORLD_TEST@EXAMPLE.COM", result)
end

function tests.test_uppercase_filter_unicode()
    -- Test uppercase with Unicode characters
    local template = Template("{{ value |> uppercase }}")
    local result = template({ value = "héllo wörld" })
    -- Note: Lua's string.upper may not handle Unicode properly in all versions
    -- This test documents current behavior
    assert.equal(string.upper("héllo wörld"), result)
end

-- Error path tests

function tests.test_uppercase_filter_nil_input()
    -- Test error when input is nil
    local success, err = pcall(function()
        local template = Template("{{ value |> uppercase }}")
        template({ value = nil })
    end)
    assert.is_false(success)
    assert.match("uppercase filter expects a string", err)
end

function tests.test_uppercase_filter_number_input()
    -- Test error when input is a number
    local success, err = pcall(function()
        local template = Template("{{ value |> uppercase }}")
        template({ value = 123 })
    end)
    assert.is_false(success)
    assert.match("uppercase filter expects a string", err)
end

function tests.test_uppercase_filter_table_input()
    -- Test error when input is a table
    local success, err = pcall(function()
        local template = Template("{{ value |> uppercase }}")
        template({ value = { key = "value" } })
    end)
    assert.is_false(success)
    assert.match("uppercase filter expects a string", err)
end

function tests.test_uppercase_filter_boolean_input()
    -- Test error when input is a boolean
    local success, err = pcall(function()
        local template = Template("{{ value |> uppercase }}")
        template({ value = true })
    end)
    assert.is_false(success)
    assert.match("uppercase filter expects a string", err)
end

-- Lowercase filter tests

function tests.test_lowercase_filter_basic()
    -- Test basic lowercase conversion
    local template = Template("{{ value |> lowercase }}")
    local result = template({ value = "HELLO WORLD" })
    assert.equal("hello world", result)
end

function tests.test_lowercase_filter_empty_string()
    -- Test lowercase with empty string
    local template = Template("{{ value |> lowercase }}")
    local result = template({ value = "" })
    assert.equal("", result)
end

function tests.test_lowercase_filter_mixed_case()
    -- Test lowercase with mixed case input
    local template = Template("{{ value |> lowercase }}")
    local result = template({ value = "HeLLo WoRlD" })
    assert.equal("hello world", result)
end

function tests.test_lowercase_filter_numbers()
    -- Test lowercase with numbers (should pass through unchanged)
    local template = Template("{{ value |> lowercase }}")
    local result = template({ value = "HELLO123WORLD" })
    assert.equal("hello123world", result)
end

function tests.test_lowercase_filter_special_chars()
    -- Test lowercase with special characters
    local template = Template("{{ value |> lowercase }}")
    local result = template({ value = "HELLO-WORLD_TEST@EXAMPLE.COM" })
    assert.equal("hello-world_test@example.com", result)
end

function tests.test_lowercase_filter_unicode()
    -- Test lowercase with Unicode characters
    local template = Template("{{ value |> lowercase }}")
    local result = template({ value = "HÉLLO WÖRLD" })
    -- Note: Lua's string.lower may not handle Unicode properly in all versions
    -- This test documents current behavior
    assert.equal(string.lower("HÉLLO WÖRLD"), result)
end

-- Error path tests for lowercase

function tests.test_lowercase_filter_nil_input()
    -- Test error when input is nil
    local success, err = pcall(function()
        local template = Template("{{ value |> lowercase }}")
        template({ value = nil })
    end)
    assert.is_false(success)
    assert.match("lowercase filter expects a string", err)
end

function tests.test_lowercase_filter_number_input()
    -- Test error when input is a number
    local success, err = pcall(function()
        local template = Template("{{ value |> lowercase }}")
        template({ value = 123 })
    end)
    assert.is_false(success)
    assert.match("lowercase filter expects a string", err)
end

function tests.test_lowercase_filter_table_input()
    -- Test error when input is a table
    local success, err = pcall(function()
        local template = Template("{{ value |> lowercase }}")
        template({ value = { key = "value" } })
    end)
    assert.is_false(success)
    assert.match("lowercase filter expects a string", err)
end

function tests.test_lowercase_filter_boolean_input()
    -- Test error when input is a boolean
    local success, err = pcall(function()
        local template = Template("{{ value |> lowercase }}")
        template({ value = true })
    end)
    assert.is_false(success)
    assert.match("lowercase filter expects a string", err)
end

-- Capitalize filter tests

function tests.test_capitalize_filter_basic()
    -- Test basic capitalization
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "hello world" })
    assert.equal("Hello World", result)
end

function tests.test_capitalize_filter_empty_string()
    -- Test capitalize with empty string
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "" })
    assert.equal("", result)
end

function tests.test_capitalize_filter_mixed_case()
    -- Test capitalize with mixed case input
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "hElLo WoRlD" })
    assert.equal("Hello World", result)
end

function tests.test_capitalize_filter_hyphenated()
    -- Test capitalize with hyphenated words
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "hello-world test-case" })
    assert.equal("Hello-World Test-Case", result)
end

function tests.test_capitalize_filter_underscored()
    -- Test capitalize with underscored words
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "hello_world test_case" })
    assert.equal("Hello_World Test_Case", result)
end

function tests.test_capitalize_filter_numbers()
    -- Test capitalize with numbers (should not affect them)
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "hello123 world456" })
    assert.equal("Hello123 World456", result)
end

function tests.test_capitalize_filter_special_chars()
    -- Test capitalize with special characters
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "hello@world.com test@example.org" })
    assert.equal("Hello@World.Com Test@Example.Org", result)
end

function tests.test_capitalize_filter_single_word()
    -- Test capitalize with single word
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "hello" })
    assert.equal("Hello", result)
end

function tests.test_capitalize_filter_already_capitalized()
    -- Test capitalize with already capitalized words
    local template = Template("{{ value |> capitalize }}")
    local result = template({ value = "Hello World" })
    assert.equal("Hello World", result)
end

-- Error path tests for capitalize

function tests.test_capitalize_filter_nil_input()
    -- Test error when input is nil
    local success, err = pcall(function()
        local template = Template("{{ value |> capitalize }}")
        template({ value = nil })
    end)
    assert.is_false(success)
    assert.match("capitalize filter expects a string", err)
end

function tests.test_capitalize_filter_number_input()
    -- Test error when input is a number
    local success, err = pcall(function()
        local template = Template("{{ value |> capitalize }}")
        template({ value = 123 })
    end)
    assert.is_false(success)
    assert.match("capitalize filter expects a string", err)
end

function tests.test_capitalize_filter_table_input()
    -- Test error when input is a table
    local success, err = pcall(function()
        local template = Template("{{ value |> capitalize }}")
        template({ value = { key = "value" } })
    end)
    assert.is_false(success)
    assert.match("capitalize filter expects a string", err)
end

function tests.test_capitalize_filter_boolean_input()
    -- Test error when input is a boolean
    local success, err = pcall(function()
        local template = Template("{{ value |> capitalize }}")
        template({ value = true })
    end)
    assert.is_false(success)
    assert.match("capitalize filter expects a string", err)
end

-- Truncate filter tests

function tests.test_truncate_filter_basic()
    -- Test basic truncation
    local template = Template("{{ value |> truncate(10) }}")
    local result = template({ value = "hello world this is a long string" })
    assert.equal("hello worl", result)
end

function tests.test_truncate_filter_shorter_than_length()
    -- Test string shorter than length (should return unchanged)
    local template = Template("{{ value |> truncate(20) }}")
    local result = template({ value = "short string" })
    assert.equal("short string", result)
end

function tests.test_truncate_filter_exact_length()
    -- Test string exactly matching length
    local template = Template("{{ value |> truncate(12) }}")
    local result = template({ value = "hello world!" })
    assert.equal("hello world!", result)
end

function tests.test_truncate_filter_empty_string()
    -- Test truncate with empty string
    local template = Template("{{ value |> truncate(5) }}")
    local result = template({ value = "" })
    assert.equal("", result)
end

function tests.test_truncate_filter_zero_length()
    -- Test truncate to zero length
    local template = Template("{{ value |> truncate(0) }}")
    local result = template({ value = "hello world" })
    assert.equal("", result)
end

function tests.test_truncate_filter_unicode()
    -- Test truncate with Unicode characters
    -- Note: Lua string operations work on bytes, not characters
    -- "héllo wörld" is 13 bytes, so truncate(5) gives first 5 bytes
    local template = Template("{{ value |> truncate(5) }}")
    local result = template({ value = "héllo wörld" })
    assert.equal("héll", result)  -- "é" is 2 bytes, so we get "héll" (5 bytes)
end

function tests.test_truncate_filter_multibyte_chars()
    -- Test truncate with multibyte UTF-8 characters
    -- Note: Lua string operations work on bytes, not characters
    -- Greek letters are 2 bytes each, so truncate(3) cuts in middle of 2nd character
    local template = Template("{{ value |> truncate(3) }}")
    local result = template({ value = "αβγδε" })
    -- Result should be exactly 3 bytes: "α" (2 bytes) + 1 byte from "β"
    assert.equal(3, #result)
    assert.equal("α", result:sub(1, 2))  -- First 2 bytes should be "α"
    -- The 3rd byte should be the first byte of "β" (which is 0xCE)
    assert.equal(206, string.byte(result, 3))  -- 0xCE is first byte of "β"
end

-- Error path tests for truncate

function tests.test_truncate_filter_nil_input()
    -- Test error when input is nil
    local success, err = pcall(function()
        local template = Template("{{ value |> truncate(5) }}")
        template({ value = nil })
    end)
    assert.is_false(success)
    assert.match("truncate filter expects a string", err)
end

function tests.test_truncate_filter_number_input()
    -- Test error when input is a number
    local success, err = pcall(function()
        local template = Template("{{ value |> truncate(5) }}")
        template({ value = 123 })
    end)
    assert.is_false(success)
    assert.match("truncate filter expects a string", err)
end

function tests.test_truncate_filter_table_input()
    -- Test error when input is a table
    local success, err = pcall(function()
        local template = Template("{{ value |> truncate(5) }}")
        template({ value = { key = "value" } })
    end)
    assert.is_false(success)
    assert.match("truncate filter expects a string", err)
end

function tests.test_truncate_filter_boolean_input()
    -- Test error when input is a boolean
    local success, err = pcall(function()
        local template = Template("{{ value |> truncate(5) }}")
        template({ value = true })
    end)
    assert.is_false(success)
    assert.match("truncate filter expects a string", err)
end

function tests.test_truncate_filter_negative_length()
    -- Test error when length is negative
    local success, err = pcall(function()
        local template = Template("{{ value |> truncate(-1) }}")
        template({ value = "hello world" })
    end)
    assert.is_false(success)
    assert.match("truncate filter expects a positive integer length", err)
end

function tests.test_truncate_filter_float_length()
    -- Test error when length is a float
    local success, err = pcall(function()
        local template = Template("{{ value |> truncate(5.5) }}")
        template({ value = "hello world" })
    end)
    assert.is_false(success)
    assert.match("truncate filter expects a positive integer length", err)
end

function tests.test_truncate_filter_string_length()
    -- Test error when length is a string
    local success, err = pcall(function()
        local template = Template("{{ value |> truncate('5') }}")
        template({ value = "hello world" })
    end)
    assert.is_false(success)
    assert.match("truncate filter expects a positive integer length", err)
end

function tests.test_truncate_filter_nil_length()
    -- Test error when length is nil
    local success, err = pcall(function()
        local template = Template("{{ value |> truncate(nil) }}")
        template({ value = "hello world" })
    end)
    assert.is_false(success)
    assert.match("truncate filter expects a positive integer length", err)
end

-- Length filter tests

function tests.test_length_filter_string()
    -- Test length of string
    local template = Template("{{ value |> length }}")
    local result = template({ value = "hello world" })
    assert.equal("11", result)  -- Template output is always string
end

function tests.test_length_filter_empty_string()
    -- Test length of empty string
    local template = Template("{{ value |> length }}")
    local result = template({ value = "" })
    assert.equal("0", result)
end

function tests.test_length_filter_unicode_string()
    -- Test length of Unicode string (byte length, not character count)
    local template = Template("{{ value |> length }}")
    local result = template({ value = "héllo wörld" })
    assert.equal("13", result)  -- 13 bytes
end

function tests.test_length_filter_array()
    -- Test length of array (table with numeric indices)
    local template = Template("{{ value |> length }}")
    local result = template({ value = { "a", "b", "c", "d" } })
    assert.equal("4", result)
end

function tests.test_length_filter_empty_array()
    -- Test length of empty array
    local template = Template("{{ value |> length }}")
    local result = template({ value = {} })
    assert.equal("0", result)
end

function tests.test_length_filter_hash_table()
    -- Test length of hash table (count of keys)
    local template = Template("{{ value |> length }}")
    local result = template({ value = { key1 = "value1", key2 = "value2", key3 = "value3" } })
    assert.equal("3", result)
end

function tests.test_length_filter_mixed_table()
    -- Test length of mixed table (numeric and string keys)
    local template = Template("{{ value |> length }}")
    local result = template({ value = { "first", key = "value", "second" } })
    assert.equal("3", result)  -- 2 array elements + 1 hash key
end

function tests.test_length_filter_sparse_array()
    -- Test length of sparse array (holes in numeric indices)
    local template = Template("{{ value |> length }}")
    local result = template({ value = { [1] = "a", [3] = "c", [5] = "e" } })
    assert.equal("3", result)  -- Count of actual keys, not highest index
end

-- Error path tests for length

function tests.test_length_filter_nil_input()
    -- Test error when input is nil
    local success, err = pcall(function()
        local template = Template("{{ value |> length }}")
        template({ value = nil })
    end)
    assert.is_false(success)
    assert.match("length filter expects a string or table", err)
end

function tests.test_length_filter_number_input()
    -- Test error when input is a number
    local success, err = pcall(function()
        local template = Template("{{ value |> length }}")
        template({ value = 123 })
    end)
    assert.is_false(success)
    assert.match("length filter expects a string or table", err)
end

function tests.test_length_filter_boolean_input()
    -- Test error when input is a boolean
    local success, err = pcall(function()
        local template = Template("{{ value |> length }}")
        template({ value = true })
    end)
    assert.is_false(success)
    assert.match("length filter expects a string or table", err)
end

-- First filter tests

function tests.test_first_filter_string()
    -- Test first character of string
    local template = Template("{{ value |> first }}")
    local result = template({ value = "hello world" })
    assert.equal("h", result)
end

function tests.test_first_filter_empty_string()
    -- Test first character of empty string
    local template = Template("{{ value |> first }}")
    local result = template({ value = "" })
    assert.equal("", result)
end

function tests.test_first_filter_single_char_string()
    -- Test first character of single character string
    local template = Template("{{ value |> first }}")
    local result = template({ value = "a" })
    assert.equal("a", result)
end

function tests.test_first_filter_unicode_string()
    -- Test first character of Unicode string
    -- Note: Lua string.sub works on bytes, not characters
    -- "αβγ" is 6 bytes, first byte is 0xCE (206 decimal)
    local template = Template("{{ value |> first }}")
    local result = template({ value = "αβγ" })
    assert.equal(string.char(206), result)  -- First byte (0xCE)
end

function tests.test_first_filter_array()
    -- Test first element of array
    local template = Template("{{ value |> first }}")
    local result = template({ value = { "first", "second", "third" } })
    assert.equal("first", result)
end

function tests.test_first_filter_empty_array()
    -- Test first element of empty array
    local template = Template("{{ value |> first }}")
    local result = template({ value = {} })
    assert.equal("", result)  -- nil becomes empty string in templates
end

function tests.test_first_filter_single_element_array()
    -- Test first element of single element array
    local template = Template("{{ value |> first }}")
    local result = template({ value = { "only" } })
    assert.equal("only", result)
end

function tests.test_first_filter_hash_table()
    -- Test first element of hash table (returns nil since no index 1)
    local template = Template("{{ value |> first }}")
    local result = template({ value = { key1 = "value1", key2 = "value2" } })
    assert.equal("", result)  -- nil becomes empty string in templates
end

function tests.test_first_filter_mixed_table()
    -- Test first element of mixed table (prioritizes array part)
    local template = Template("{{ value |> first }}")
    local result = template({ value = { "array_item", key = "hash_value" } })
    assert.equal("array_item", result)  -- Array element comes first
end

function tests.test_first_filter_sparse_array()
    -- Test first element of sparse array
    local template = Template("{{ value |> first }}")
    local result = template({ value = { [3] = "third", [1] = "first", [5] = "fifth" } })
    assert.equal("first", result)  -- Index 1 exists
end

-- Error path tests for first

function tests.test_first_filter_nil_input()
    -- Test error when input is nil
    local success, err = pcall(function()
        local template = Template("{{ value |> first }}")
        template({ value = nil })
    end)
    assert.is_false(success)
    assert.match("first filter expects a string or table", err)
end

function tests.test_first_filter_number_input()
    -- Test error when input is a number
    local success, err = pcall(function()
        local template = Template("{{ value |> first }}")
        template({ value = 123 })
    end)
    assert.is_false(success)
    assert.match("first filter expects a string or table", err)
end

function tests.test_first_filter_boolean_input()
    -- Test error when input is a boolean
    local success, err = pcall(function()
        local template = Template("{{ value |> first }}")
        template({ value = true })
    end)
    assert.is_false(success)
    assert.match("first filter expects a string or table", err)
end

return tests