local assert = require("luassert")
local Application = require("nibiru.application")
local http = require("nibiru.http")
local Route = require("nibiru.route")
local Template = require("nibiru.template")

local tests = {}

function tests.test_constructor()
    Template.clear_templates()
    local app = Application(nil, "tests/data/config.lua")

    assert.equal(Application, getmetatable(app))
    assert.equal(app, app.app)
end

-- The app behaves like a WSGI callable.
function tests.test_app_is_wsgi_callable()
    Template.clear_templates()
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
    end) }, "tests/data/config.lua")

    app(environ, start_response)

    assert.is_true(start_response_called)
    assert.equal("200 OK", actual_status)
    assert.same({}, actual_response_headers)
end

-- The app finds routes.
function tests.test_find_routes()
    Template.clear_templates()
    local match, actual_route
    local route_a = Route("/users", function() end)
    local route_b = Route("/other", function() end)
    local routes = { route_a, route_b }
    local app = Application(routes, "tests/data/config.lua")

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

-- The app loads config and templates automatically
function tests.test_config_and_template_loading()
    Template.clear_templates()
    local app = Application(nil, "tests/data/config.lua")

    -- Check that config was loaded from test config
    assert.is_table(app.config)
    assert.is_table(app.config.templates)
    assert.equal("tests/data/test_templates", app.config.templates.directory)
end

-- The app maintains a lookup table of routes by name.
function tests.test_route_name_lookup()
    Template.clear_templates()
    local route_a = Route("/users", function() end, "users_list")
    local route_b = Route("/posts", function() end, "posts_list")
    local route_c = Route("/admin", function() end) -- no name
    local routes = { route_a, route_b, route_c }
    local app = Application(routes, "tests/data/config.lua")

    assert.equal(route_a, app.routes_by_name["users_list"])
    assert.equal(route_b, app.routes_by_name["posts_list"])
    assert.is_nil(app.routes_by_name["admin"])
end

-- The app errors on duplicate route names.
function tests.test_duplicate_route_names()
    Template.clear_templates()
    local route_a = Route("/users", function() end, "duplicate_name")
    local route_b = Route("/posts", function() end, "duplicate_name")
    local routes = { route_a, route_b }

    local status, msg = pcall(function()
        Application(routes, "tests/data/config.lua")
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Duplicate route name: duplicate_name", 1, true))
end

return tests
