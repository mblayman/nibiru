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

return tests
