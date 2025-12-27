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

-- The app can generate URLs for named routes.
function tests.test_url_for_basic()
    Template.clear_templates()
    local route_a = Route("/users/{id:integer}", function() end, "user_detail")
    local route_b = Route("/posts/{year:integer}/{slug:string}", function() end, "post_detail")
    local route_c = Route("/home", function() end, "home")
    local routes = { route_a, route_b, route_c }
    local app = Application(routes, "tests/data/config.lua")

    assert.equal("/users/123", app:url_for("user_detail", 123))
    assert.equal("/posts/2024/hello-world", app:url_for("post_detail", 2024, "hello-world"))
    assert.equal("/home", app:url_for("home"))
end

-- The app errors when route name is unknown.
function tests.test_url_for_unknown_route()
    Template.clear_templates()
    local routes = { Route("/test", function() end, "known_route") }
    local app = Application(routes, "tests/data/config.lua")

    local status, msg = pcall(function()
        app:url_for("unknown_route")
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Unknown route name: unknown_route", 1, true))
end

-- The app passes through parameter validation errors from routes.
function tests.test_url_for_parameter_validation()
    Template.clear_templates()
    local route = Route("/users/{id:integer}", function() end, "user_detail")
    local routes = { route }
    local app = Application(routes, "tests/data/config.lua")

    -- Wrong number of parameters
    local status1, msg1 = pcall(function()
        app:url_for("user_detail")
    end)
    assert.is_false(status1)
    assert.is_not_nil(string.find(msg1 or "", "Route requires 1 parameters, got 0", 1, true))

    -- Too many parameters
    local status2, msg2 = pcall(function()
        app:url_for("user_detail", 123, "extra")
    end)
    assert.is_false(status2)
    assert.is_not_nil(string.find(msg2 or "", "Route requires 1 parameters, got 2", 1, true))

    -- Nil parameter
    local status3, msg3 = pcall(function()
        app:url_for("user_detail", nil)
    end)
    assert.is_false(status3)
    assert.is_not_nil(string.find(msg3 or "", "Parameter 1 cannot be nil", 1, true))

    -- Invalid integer
    local status4, msg4 = pcall(function()
        app:url_for("user_detail", "not-a-number")
    end)
    assert.is_false(status4)
    assert.is_not_nil(string.find(msg4 or "", "Parameter 1 must be a valid integer", 1, true))
end

-- The app handles routes with string parameters.
function tests.test_url_for_string_parameters()
    Template.clear_templates()
    local route = Route("/posts/{slug:string}", function() end, "post_detail")
    local routes = { route }
    local app = Application(routes, "tests/data/config.lua")

    assert.equal("/posts/my-article", app:url_for("post_detail", "my-article"))
    assert.equal("/posts/another_post_123", app:url_for("post_detail", "another_post_123"))
end

-- The app handles routes with multiple parameters.
function tests.test_url_for_multiple_parameters()
    Template.clear_templates()
    local route = Route("/blog/{year:integer}/{month:integer}/{slug:string}", function() end, "blog_post")
    local routes = { route }
    local app = Application(routes, "tests/data/config.lua")

    assert.equal("/blog/2024/12/my-article", app:url_for("blog_post", 2024, 12, "my-article"))
end

return tests
