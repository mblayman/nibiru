local assert = require("luassert")
local Template = require("nibiru.template")

local tests = {}

-- Core filter functionality tests (happy paths)

function tests.test_filter_pipeline_basic()
    -- Test basic filter application
    Template.register_filter("test_double", function(value)
        return value * 2
    end)

    local template = Template("{{ value |> test_double }}")
    print("Generated code:", template.code)
    local result = template({ value = 5 })
    assert.equal("10", result)

    -- Clean up
    Template.clear_filters()
end

function tests.test_filter_pipeline_chaining()
    -- Test chaining multiple filters
    Template.register_filter("add_one", function(value)
        return value + 1
    end)
    Template.register_filter("multiply_two", function(value)
        return value * 2
    end)

    local template = Template("{{ value |> add_one |> multiply_two }}")
    local result = template({ value = 3 })
    assert.equal("8", result)  -- (3 + 1) * 2 = 8

    Template.clear_filters()
end

function tests.test_filter_pipeline_with_arguments()
    -- Test filters that accept arguments
    Template.register_filter("add_value", function(input, amount)
        return input + amount
    end)

    local template = Template("{{ value |> add_value(10) }}")
    local result = template({ value = 5 })
    assert.equal("15", result)

    Template.clear_filters()
end

function tests.test_filter_pipeline_multiple_arguments()
    -- Test filters with multiple arguments
    Template.register_filter("combine", function(a, b, c)
        return a .. b .. c
    end)

    local template = Template('{{ value |> combine("-", "end") }}')
    local result = template({ value = "start" })
    assert.equal("start-end", result)

    Template.clear_filters()
end

function tests.test_filter_pipeline_expression_arguments()
    -- Test arguments that are expressions
    Template.register_filter("add_values", function(a, b)
        return a + b
    end)

    local template = Template("{{ value |> add_values(count * 2) }}")
    print("Generated code:", template.code)
    local result = template({ value = 10, count = 3 })
    assert.equal("16", result)  -- 10 + (3 * 2) = 16

    Template.clear_filters()
end

function tests.test_filter_pipeline_variable_arguments()
    -- Test arguments that reference context variables
    Template.register_filter("concat", function(a, b)
        return a .. b
    end)

    local template = Template("{{ value |> concat(suffix) }}")
    local result = template({ value = "hello", suffix = " world" })
    assert.equal("hello world", result)

    Template.clear_filters()
end

function tests.test_filter_pipeline_nil_handling()
    -- Test filters handle nil inputs gracefully
    Template.register_filter("safe_string", function(value)
        return value or "default"
    end)

    local template = Template("{{ value |> safe_string }}")
    local result = template({ value = nil })
    assert.equal("default", result)

    Template.clear_filters()
end

function tests.test_filter_pipeline_in_component()
    -- Test filters work within component templates
    Template.register_filter("uppercase", function(value)
        return string.upper(value)
    end)

    Template.component("TestComp", [[<div>{{ text |> uppercase }}</div>]])

    local template = Template('<TestComp text="hello"/>')
    local result = template({})
    assert.equal("<div>HELLO</div>", result)

    Template.clear_components()
    Template.clear_filters()
end

-- Error path tests for core filter functionality

function tests.test_filter_pipeline_unknown_filter()
    -- Test error for unregistered filter
    local success, err = pcall(function()
        local template = Template("{{ value |> nonexistent }}")
        template({ value = "test" })
    end)
    assert.is_false(success)
    assert.match("Unknown filter 'nonexistent'", err)
end

function tests.test_filter_pipeline_invalid_syntax_missing_filter()
    -- Test error for incomplete pipeline
    local success, err = pcall(function()
        local template = Template("{{ value |> }}")
        template({ value = "test" })
    end)
    assert.is_false(success)
    assert.match("Expected filter name after |> operator", err)
end

function tests.test_filter_pipeline_invalid_syntax_incomplete_chain()
    -- Test error for malformed chain
    local success, err = pcall(function()
        local template = Template("{{ value |> filter1 |> }}")
        template({ value = "test" })
    end)
    assert.is_false(success)
    assert.match("Unknown filter 'filter1'", err)
end

function tests.test_filter_pipeline_non_function_filter()
    -- Test error when filter is not a function
    local success, err = pcall(function()
        Template.register_filter("not_a_function", "string_value")
    end)
    assert.is_false(success)
    assert.match("Filter 'not_a_function' must be a function", err)

    Template.clear_filters()
end

function tests.test_filter_pipeline_too_many_arguments()
    -- Test error when filter receives unexpected arguments
    Template.register_filter("no_args", function(value, ...)
        local arg_count = select('#', ...)
        if arg_count > 0 then
            error("no_args filter takes no additional arguments, got " .. arg_count)
        end
        return value
    end)

    local success, err = pcall(function()
        local template = Template("{{ value |> no_args(1, 2) }}")
        template({ value = "test" })
    end)
    assert.is_false(success)
    assert.match("no_args filter takes no additional arguments", err)

    Template.clear_filters()
end

function tests.test_filter_pipeline_missing_required_arguments()
    -- Test error when required arguments are missing
    Template.register_filter("requires_arg", function(value, arg)
        if not arg then
            error("requires_arg filter needs an argument")
        end
        return value .. arg
    end)

    local success, err = pcall(function()
        local template = Template("{{ value |> requires_arg }}")
        template({ value = "test" })
    end)
    assert.is_false(success)
    assert.match("requires_arg filter needs an argument", err)

    Template.clear_filters()
end

function tests.test_filter_registration_duplicate_name()
    -- Test error when registering a filter with a name that already exists
    Template.register_filter("unique_filter", function(value)
        return value .. "_filtered"
    end)

    local success, err = pcall(function()
        Template.register_filter("unique_filter", function(value)
            return value .. "_different"
        end)
    end)
    assert.is_false(success)
    assert.match("Filter 'unique_filter' is already registered", err)

    Template.clear_filters()
end

return tests
