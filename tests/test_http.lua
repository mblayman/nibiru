local assert = require("luassert")
local http = require("nibiru.http")

local tests = {}

-- A response has defaults of an empty 200 OK.
function tests.test_response()
    local response = http.Response()

    assert.equal(getmetatable(response), http.Response)
    assert.equal(response.status_code, 200)
    assert.equal(response.content, "")
    assert.equal(response.content_type, "text/html")
    assert.same(response.headers, {})
end

-- A response holds the supplied values.
function tests.test_response_with_values()
    local response =
        http.Response(404, "Page not found", "text/plain", { hello = "world" })

    assert.equal(response.status_code, 404)
    assert.equal(response.content, "Page not found")
    assert.equal(response.content_type, "text/plain")
    assert.same(response.headers, { hello = "world" })
end

-- ok is a shortcut to create a 200 response.
function tests.test_ok()
    local response = http.ok("success", "text/plain", { hello = "world" })

    assert.equal(response.status_code, 200)
    assert.equal(response.content, "success")
    assert.equal(response.content_type, "text/plain")
    assert.same(response.headers, { hello = "world" })
end

return tests
