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

-- An invalid request receives a 400 response.
function tests.test_invalid_request()
    local data = "invalid"
    local application = function() end

    local response = connector.handle_connection(application, data)

    assert.equal("HTTP/1.1 400 Bad Request\r\n\r\n", response)
end

-- An unsupported version receives a 505 response.
function tests.test_unsupported_version()
    local data = "GET / HTTP/99\r\n\r\n"
    local application = function() end

    local response = connector.handle_connection(application, data)

    assert.equal("HTTP/1.1 505 HTTP Version Not Supported\r\n\r\n", response)
end

-- An unsupported method receives a 501 response.
function tests.test_unsupported_method()
    local data = "INVALID / HTTP/1.1\r\n\r\n"
    local application = function() end

    local response = connector.handle_connection(application, data)

    assert.equal("HTTP/1.1 501 Not Implemented\r\n\r\n", response)
end

return tests
