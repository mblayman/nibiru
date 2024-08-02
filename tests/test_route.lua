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
    assert.same({ "GET", "POST" }, route.methods)
end

-- When no methods are provided, only GET is allowed.
function tests.test_optional_methods()
    local path = "/hello"
    local controller = function() end
    local route = Route(path, controller)

    assert.same({ "GET" }, route.methods)
end

return tests
