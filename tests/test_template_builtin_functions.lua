local assert = require("luassert")
local Template = require("nibiru.template")

local tests = {}

-- Core function functionality tests (happy paths)

function tests.test_function_concat_basic()
    -- Test basic concat function usage
    Template.clear_components()
    Template.clear_functions()

    Template.register_function("concat", function(context, a, b)
        return tostring(a or "") .. tostring(b or "")
    end)

    local template = Template("{{ concat('hello', 'world') }}")
    local result = template({})
    assert.equal("helloworld", result)

    Template.clear_functions()
end

function tests.test_function_concat_with_variables()
    -- Test concat function with variables
    Template.clear_components()
    Template.clear_functions()

    Template.register_function("concat", function(context, a, b)
        return tostring(a or "") .. tostring(b or "")
    end)

    local template = Template("{{ concat(prefix, suffix) }}")
    local result = template({ prefix = "pre", suffix = "fix" })
    assert.equal("prefix", result)

    Template.clear_functions()
end

function tests.test_function_concat_in_component()
    -- Test concat function in component
    Template.clear_components()
    Template.clear_functions()

    Template.register_function("concat", function(context, a, b)
        return tostring(a or "") .. tostring(b or "")
    end)

    Template.component("TestComp", [[<div>{{ concat(a, b) }}</div>]])

    local template = Template('<TestComp a="hello" b="world"/>')
    local result = template({})
    assert.equal("<div>helloworld</div>", result)

    Template.clear_components()
    Template.clear_functions()
end

function tests.test_function_unknown_function()
    -- Test error for calling non-existent function
    Template.clear_components()
    Template.clear_functions()

    local success, err = pcall(function()
        local template = Template("{{ nonexistent_func('arg') }}")
        template({})
    end)
    assert.is_false(success)
    assert.match("Unknown function 'nonexistent_func'", err)
end

return tests