local assert = require("luassert")
local Route = require("nibiru.route")

local tests = {}

function tests.test_constructor()
    local path = "/hello"
    local controller = function() end
    local route = Route(path, controller, { "GET", "POST" })

    assert.equal(Route, getmetatable(route))
    assert.equal(path, route.path)
    assert.equal(controller, route.controller)
    assert.same({ GET = true, POST = true }, route.methods)
end

-- When no methods are provided, only GET is allowed.
function tests.test_optional_methods()
    local path = "/hello"
    local controller = function() end
    local route = Route(path, controller)

    assert.same({ GET = true }, route.methods)
end

-- Only allowed methods can match.
function tests.test_allowed_methods()
    local methods = { "GET", "POST" }
    local route = Route("/", function() end, methods)

    assert.equal(Route.NOT_ALLOWED, route:matches("DELETE", "/"))
    -- TODO: enable asserts when path matching works
    -- assert.equal(Route.MATCH, route:matches("GET", "/"))
    -- assert.equal(Route.MATCH, route:matches("POST", "/"))
end

-- Route generates path pattern with no parameter.
function tests.test_no_parameter_pattern()
    local controller = function() end
    local route = Route("/users", controller)

    assert.equal("^/users$", route.path_pattern)
    assert.same({}, route.converters)
end

-- Route generates path pattern with one parameter.
function tests.test_one_parameter_pattern()
    local controller = function() end
    local route = Route("/users/{id:integer}", controller)

    assert.equal("^/users/([%d]*)$", route.path_pattern)
    assert.same({ "integer" }, route.converters)
end

-- Route generates path pattern with multiple parameters.
function tests.test_multiple_parameters_pattern()
    local controller = function() end
    local route = Route("/users/{username:string}/posts/{id:integer}", controller)

    assert.equal("^/users/([^/]*)/posts/([%d]*)$", route.path_pattern)
    assert.same({ "string", "integer" }, route.converters)
end

-- Route fails with an unknown converter.
function tests.test_unknown_converter()
    local controller = function() end
    local status, message = pcall(Route, "/users/{id:nope}", controller)

    assert.is_false(status)
    assert.is_not_nil(string.find(message, "Unknown converter type: nope", 1, true))
end

return tests
