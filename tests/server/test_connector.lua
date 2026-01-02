local assert = require("luassert")
local connector = require("nibiru.server.connector")

local tests = {}

-- start_response captures the status and response headers.
function tests.test_start_response()
    local status = "200 OK"
    local response_headers = { hello = "world" }

    connector.start_response(status, response_headers)

    assert.equal(status, connector.status)
    assert.same(response_headers, connector.response_headers)
end

-- Test valid connection handling (error cases now handled in C)
function tests.test_valid_connection()
    local application = function(environ, start_response)
        start_response("200 OK", {})
        -- Return an iterator (ipairs works on tables)
        return ipairs({"Hello, World!"})
    end

    local response = connector.handle_connection(application, "GET", "/", "HTTP/1.1", "\r\n")

    -- Should contain the response from the application
    assert.truthy(string.find(response, "200 OK"))
    assert.truthy(string.find(response, "Hello, World!"))
end

return tests
