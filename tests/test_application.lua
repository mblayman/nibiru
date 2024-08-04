local assert = require("luassert")
local Application = require("nibiru.application")
local http = require("nibiru.http")
local Route = require("nibiru.route")

local tests = {}

function tests.test_constructor()
    local app = Application()

    assert.equal(Application, getmetatable(app))
    assert.equal(app, app.app)
end

-- The app behaves like a WSGI callable.
function tests.test_app_is_wsgi_callable()
    local start_response_called = false
    local actual_status = ""
    local actual_response_headers = nil
    local environ = { REQUEST_METHOD = "GET", PATH_INFO = "/" }
    local start_response = function(status, response_headers)
        start_response_called = true
        actual_status = status
        actual_response_headers = response_headers
    end
    local app = Application({ Route("/", function()
        return http.ok()
    end) })

    app(environ, start_response)

    assert.is_true(start_response_called)
    assert.equal("200 OK", actual_status)
    assert.same({}, actual_response_headers)
end

-- The app finds routes.
function tests.test_find_routes()
    local match, actual_route
    local route_a = Route("/users", function() end)
    local route_b = Route("/other", function() end)
    local routes = { route_a, route_b }
    local app = Application(routes)

    match, actual_route = app:find_route("GET", "/users")
    assert.equal(Route.MATCH, match)
    assert.equal(route_a, actual_route)

    match, actual_route = app:find_route("POST", "/users")
    assert.equal(Route.NOT_ALLOWED, match)
    assert.equal(route_a, actual_route)

    match, actual_route = app:find_route("GET", "/other")
    assert.equal(Route.MATCH, match)
    assert.equal(route_b, actual_route)

    match, actual_route = app:find_route("GET", "/third")
    assert.equal(Route.NO_MATCH, match)
    assert.is_nil(actual_route)
end

return tests
