local assert = require("luassert")
local parser = require("nibiru.server.http_parser")
local ParserErrors = parser.ParserErrors

local tests = {}

-- A valid request is parsed.
function tests.test_valid_request()
    local method = "GET"
    local target = "/"
    local version = "HTTP/1.1"
    local remaining_data = "\r\n"

    local environ, err = parser.parse(method, target, version, remaining_data)

    assert.is_nil(err)
    if environ == nil then
        assert.is_true(false)
        return
    end
    assert.equal("GET", environ.REQUEST_METHOD)
    assert.equal("/", environ.PATH_INFO)
    assert.equal("HTTP/1.1", environ.SERVER_PROTOCOL)
end

-- Parser now only accepts pre-validated inputs, so error tests are removed
-- (validation is done in C)

return tests
