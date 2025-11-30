local assert = require("luassert")
local http = require("nibiru.http")
local Route = require("nibiru.route")

local tests = {}

function tests.test_constructor()
    local path = "/hello"
    local responder = function() end
    local route = Route(path, responder, { "GET", "POST" })

    assert.equal(Route, getmetatable(route))
    assert.equal(path, route.path)
    assert.equal(responder, route.responder)
    assert.same({ GET = true, POST = true }, route.methods)
end

-- When no methods are provided, only GET is allowed.
function tests.test_optional_methods()
    local path = "/hello"
    local responder = function() end
    local route = Route(path, responder)

    assert.same({ GET = true }, route.methods)
end

-- Only allowed methods match.
function tests.test_allowed_methods()
    local methods = { "GET", "POST" }
    local route = Route("/", function() end, methods)

    assert.equal(Route.NOT_ALLOWED, route:matches("DELETE", "/"))
    assert.equal(Route.MATCH, route:matches("GET", "/"))
    assert.equal(Route.MATCH, route:matches("POST", "/"))
end

-- Literal paths match.
function tests.test_literal_path()
    local route = Route("/simple", function() end)

    assert.equal(Route.MATCH, route:matches("GET", "/simple"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/other"))
end

-- String paths match.
function tests.test_string_path()
    local route = Route("/users/{username:string}", function() end)

    assert.equal(Route.MATCH, route:matches("GET", "/users/matt"))
    assert.equal(Route.MATCH, route:matches("GET", "/users/42"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/users/"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/users/too/deep"))
end

-- Integer paths match.
function tests.test_integer_path()
    local route = Route("/users/{id:integer}", function() end)

    assert.equal(Route.MATCH, route:matches("GET", "/users/42"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/users/matt"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/users/"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/users/42/too/deep"))
end

-- Multiple parameters match.
function tests.test_multiple_parameters()
    local route = Route("/users/{username:string}/posts/{id:integer}", function() end)

    assert.equal(Route.MATCH, route:matches("GET", "/users/matt/posts/42"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/users/matt/posts/other"))
    assert.equal(Route.NO_MATCH, route:matches("GET", "/users/matt/posts/"))
end

-- Route generates path pattern with no parameter.
function tests.test_no_parameter_pattern()
    local responder = function() end
    local route = Route("/users", responder)

    assert.equal("^/users$", route.path_pattern)
    assert.same({}, route.converters)
end

-- Route generates path pattern with one parameter.
function tests.test_one_parameter_pattern()
    local responder = function() end
    local route = Route("/users/{id:integer}", responder)

    assert.equal("^/users/([%d]+)$", route.path_pattern)
    assert.same({ "integer" }, route.converters)
end

-- Route generates path pattern with multiple parameters.
function tests.test_multiple_parameters_pattern()
    local responder = function() end
    local route = Route("/users/{username:string}/posts/{id:integer}", responder)

    assert.equal("^/users/([^/]+)/posts/([%d]+)$", route.path_pattern)
    assert.same({ "string", "integer" }, route.converters)
end

-- Route fails with an unknown converter.
function tests.test_unknown_converter()
    local responder = function() end
    local status, msg = pcall(function()
        Route("/users/{id:nope}", responder)
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Unknown converter type: nope", 1, true))
end

-- Route run sends correct parameters and returns a response.
function tests.test_run()
    local actual_request, actual_username, actual_id
    local responder = function(request, username, id)
        actual_request, actual_username, actual_id = request, username, id
        return http.ok()
    end
    local route = Route("/users/{username:string}/posts/{id:integer}", responder)
    local request = http.get("/users/matt/posts/42")

    local response = route:run(request)

    assert.equal(200, response.status_code)
    assert.equal(request, actual_request)
    assert.equal("matt", actual_username)
    assert.equal(42, actual_id)
end

return tests
