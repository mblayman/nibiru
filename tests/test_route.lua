local assert = require("luassert")
local http = require("nibiru.http")
local Route = require("nibiru.route")

local tests = {}

function tests.test_constructor()
    local path = "/hello"
    local responder = function() end
    local route = Route(path, responder, "hello_route", { "GET", "POST" })

    assert.equal(Route, getmetatable(route))
    assert.equal(path, route.path)
    assert.equal(responder, route.responder)
    assert.equal("hello_route", route.name)
    assert.same({ GET = true, POST = true }, route.methods)
end

-- When no methods are provided, only GET is allowed.
function tests.test_optional_methods()
    local path = "/hello"
    local responder = function() end
    local route = Route(path, responder)

    assert.same({ GET = true }, route.methods)
end

-- Route name is optional.
function tests.test_optional_name()
    local path = "/hello"
    local responder = function() end
    local route = Route(path, responder, nil, { "GET", "POST" })

    assert.is_nil(route.name)
    assert.same({ GET = true, POST = true }, route.methods)
end

-- Only allowed methods match.
function tests.test_allowed_methods()
    local methods = { "GET", "POST" }
    local route = Route("/", function() end, nil, methods)

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

-- URL generation tests for url_for method

-- Route with no parameters generates correct URL.
function tests.test_url_for_no_parameters()
    local route = Route("/home", function() end)

    local url = route:url_for()

    assert.equal("/home", url)
end

-- Route with no parameters errors with too many arguments.
function tests.test_url_for_no_parameters_too_many_args()
    local route = Route("/home", function() end)

    local status, msg = pcall(function()
        route:url_for("extra")
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Route requires 0 parameters, got 1", 1, true))
end

-- Route with single string parameter generates correct URL.
function tests.test_url_for_single_string_parameter()
    local route = Route("/users/{username:string}", function() end)

    local url = route:url_for("matt")

    assert.equal("/users/matt", url)
end

-- Route with single integer parameter generates correct URL.
function tests.test_url_for_single_integer_parameter()
    local route = Route("/users/{id:integer}", function() end)

    local url = route:url_for(42)

    assert.equal("/users/42", url)
end

-- Route with single parameter errors with nil value.
function tests.test_url_for_single_parameter_nil_value()
    local route = Route("/users/{id:integer}", function() end)

    local status, msg = pcall(function()
        route:url_for(nil)
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Parameter 1 cannot be nil", 1, true))
end

-- Route with single parameter errors with too few arguments.
function tests.test_url_for_single_parameter_too_few_args()
    local route = Route("/users/{id:integer}", function() end)

    local status, msg = pcall(function()
        route:url_for()
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Route requires 1 parameters, got 0", 1, true))
end

-- Route with single parameter errors with too many arguments.
function tests.test_url_for_single_parameter_too_many_args()
    local route = Route("/users/{id:integer}", function() end)

    local status, msg = pcall(function()
        route:url_for(42, "extra")
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Route requires 1 parameters, got 2", 1, true))
end

-- Route with multiple parameters generates correct URL.
function tests.test_url_for_multiple_parameters()
    local route = Route("/users/{username:string}/posts/{id:integer}", function() end)

    local url = route:url_for("matt", 42)

    assert.equal("/users/matt/posts/42", url)
end

-- Route with multiple parameters errors with nil in first position.
function tests.test_url_for_multiple_parameters_nil_first()
    local route = Route("/users/{username:string}/posts/{id:integer}", function() end)

    local status, msg = pcall(function()
        route:url_for(nil, 42)
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Parameter 1 cannot be nil", 1, true))
end

-- Route with multiple parameters errors with nil in second position.
function tests.test_url_for_multiple_parameters_nil_second()
    local route = Route("/users/{username:string}/posts/{id:integer}", function() end)

    local status, msg = pcall(function()
        route:url_for("matt", nil)
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Parameter 2 cannot be nil", 1, true))
end

-- Route with multiple parameters errors with too few arguments.
function tests.test_url_for_multiple_parameters_too_few_args()
    local route = Route("/users/{username:string}/posts/{id:integer}", function() end)

    local status, msg = pcall(function()
        route:url_for("matt")
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Route requires 2 parameters, got 1", 1, true))
end

-- Route with multiple parameters errors with too many arguments.
function tests.test_url_for_multiple_parameters_too_many_args()
    local route = Route("/users/{username:string}/posts/{id:integer}", function() end)

    local status, msg = pcall(function()
        route:url_for("matt", 42, "extra")
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Route requires 2 parameters, got 3", 1, true))
end

-- Route with complex path generates correct URL.
function tests.test_url_for_complex_path()
    local route = Route("/blog/{year:integer}/{month:integer}/{slug:string}", function() end)

    local url = route:url_for(2024, 12, "my-article-title")

    assert.equal("/blog/2024/12/my-article-title", url)
end

-- Route converts integer parameters to strings.
function tests.test_url_for_integer_conversion()
    local route = Route("/users/{id:integer}", function() end)

    local url = route:url_for(123)

    assert.equal("/users/123", url)
    assert.equal("string", type(url))
end

-- Route handles string parameters with special characters.
function tests.test_url_for_string_with_special_chars()
    local route = Route("/posts/{slug:string}", function() end)

    local url = route:url_for("hello-world_post!")

    assert.equal("/posts/hello-world_post!", url)
end

-- Route rejects string parameters containing slashes.
function tests.test_url_for_string_with_slash()
    local route = Route("/posts/{slug:string}", function() end)

    local status, msg = pcall(function()
        route:url_for("hello/world")
    end)

    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Parameter 1 cannot contain forward slashes", 1, true))
end

-- Route validates integer parameter types.
function tests.test_url_for_integer_parameter_type_validation()
    local route = Route("/users/{id:integer}", function() end)

    -- Valid integer as number
    local url1 = route:url_for(42)
    assert.equal("/users/42", url1)

    -- Valid integer as string that can be converted
    local url2 = route:url_for("123")
    assert.equal("/users/123", url2)

    -- Invalid: string that cannot be converted to integer
    local status, msg = pcall(function()
        route:url_for("not-a-number")
    end)
    assert.is_false(status)
    assert.is_not_nil(string.find(msg or "", "Parameter 1 must be a valid integer", 1, true))
end

-- Route validates string parameter types (though strings are more permissive).
function tests.test_url_for_string_parameter_type_validation()
    local route = Route("/users/{name:string}", function() end)

    -- Valid string
    local url = route:url_for("matt")
    assert.equal("/users/matt", url)

    -- Numbers are converted to strings
    local url2 = route:url_for(123)
    assert.equal("/users/123", url2)
end

return tests
