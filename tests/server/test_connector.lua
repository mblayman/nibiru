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

return tests
