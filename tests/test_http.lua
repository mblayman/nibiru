local assert = require("luassert")
local http = require("nibiru.http")

local tests = {}

-- A request has defaults.
function tests.test_request()
    local request = http.Request()

    assert.equal("GET", request.method)
    assert.equal("", request.path)
end

-- A request holds the supplied arguments.
function tests.test_request_with_arguments()
    local request = http.Request("POST", "/users")

    assert.equal("POST", request.method)
    assert.equal("/users", request.path)
end

-- get is a shortcut to create a GET request.
function tests.test_get()
    local request = http.get("/users")

    assert.equal("GET", request.method)
    assert.equal("/users", request.path)
end

-- A response has defaults of an empty 200 OK.
function tests.test_response()
    local response = http.Response()

    assert.equal(http.Response, getmetatable(response))
    assert.equal(200, response.status_code)
    assert.equal("", response.content)
    assert.equal("text/html", response.content_type)
    assert.same({}, response.headers)
end

-- A response holds the supplied arguments.
function tests.test_response_with_arguments()
    local response =
        http.Response(404, "Page not found", "text/plain", { hello = "world" })

    assert.equal(404, response.status_code)
    assert.equal("Page not found", response.content)
    assert.equal("text/plain", response.content_type)
    assert.same({ hello = "world" }, response.headers)
end

-- ok is a shortcut to create a 200 response.
function tests.test_ok()
    local response = http.ok("success", "text/plain", { hello = "world" })

    assert.equal(200, response.status_code)
    assert.equal("success", response.content)
    assert.equal("text/plain", response.content_type)
    assert.same({ hello = "world" }, response.headers)
end

-- not_found is a shortcut to create a 404 response.
function tests.test_not_found()
    local response = http.not_found("nope", "text/plain", { hello = "world" })

    assert.equal(404, response.status_code)
    assert.equal("nope", response.content)
    assert.equal("text/plain", response.content_type)
    assert.same({ hello = "world" }, response.headers)
end

-- not_found has decent defaults.
function tests.test_not_found_no_arguments()
    local response = http.not_found()

    assert.equal(404, response.status_code)
    assert.equal("Not Found", response.content)
    assert.equal("text/html", response.content_type)
end

-- method_not_allowed is a shortcut to create a 404 response.
function tests.test_method_not_allowed()
    local response = http.method_not_allowed("nope", "text/plain", { hello = "world" })

    assert.equal(405, response.status_code)
    assert.equal("nope", response.content)
    assert.equal("text/plain", response.content_type)
    assert.same({ hello = "world" }, response.headers)
end

-- method_not_allowed has decent defaults.
function tests.test_method_not_allowed_no_arguments()
    local response = http.method_not_allowed()

    assert.equal(405, response.status_code)
    assert.equal("Method Not Allowed", response.content)
    assert.equal("text/html", response.content_type)
end

return tests
