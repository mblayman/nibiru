local assert = require("luassert")
local Template = require("nibiru.template")
local Route = require("nibiru.route")
local Application = require("nibiru.application")

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

-- Route function tests

function tests.test_route_function_no_application()
    -- Test that route function errors when no application is set
    Template.clear_components()
    Template.clear_application() -- Clear any existing application

    local success, err = pcall(function()
        local template = Template("{{ route('test_route') }}")
        template({})
    end)
    assert.is_false(success)
    assert.match("No application instance available", err)
end

function tests.test_route_function_with_application()
    -- Test that route function works when application is set
    Template.clear_components()
    Template.clear_templates()

    -- Create a real application with routes
    local routes = {
        Route("/test", function() end, "test_route")
    }
    local app = Application(routes, "tests/data/config.lua")

    local template = Template("{{ route('test_route') }}")
    local result = template({})
    assert.equal("/test", result)
end

function tests.test_route_function_unknown_route()
    -- Test that route function errors for unknown route names
    Template.clear_components()
    Template.clear_templates()

    -- Create a real application with routes
    local routes = {
        Route("/known", function() end, "known_route")
    }
    local app = Application(routes, "tests/data/config.lua")

    local success, err = pcall(function()
        local template = Template("{{ route('unknown_route') }}")
        template({})
    end)
    assert.is_false(success)
    assert.match("Unknown route name: unknown_route", err)
end

function tests.test_route_function_with_parameters()
    -- Test that route function passes parameters correctly
    Template.clear_components()
    Template.clear_templates()

    -- Create a real application with parameterized routes
    local routes = {
        Route("/users/{id:integer}", function() end, "user_profile")
    }
    local app = Application(routes, "tests/data/config.lua")

    local template = Template("{{ route('user_profile', 123) }}")
    local result = template({})
    assert.equal("/users/123", result)
end

function tests.test_route_function_in_component()
    -- Test that route function works within components
    Template.clear_components()
    Template.clear_templates()

    -- Create a real application with routes
    local routes = {
        Route("/", function() end, "home")
    }
    local app = Application(routes, "tests/data/config.lua")

    Template.component("Link", [[<a href="{{ route('home') }}">Home</a>]])

    local template = Template('<Link/>')
    local result = template({})
    assert.equal('<a href="/">Home</a>', result)

    Template.clear_components()
end

return tests