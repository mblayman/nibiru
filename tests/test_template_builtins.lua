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

return tests