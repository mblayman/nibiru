local assert = require("luassert")
local parser = require("nibiru.server.http_parser")
local ParserErrors = parser.ParserErrors

local tests = {}

-- A valid request is parsed.
function tests.test_valid_request()
    local data = "GET / HTTP/1.1\r\n\r\n"

    local environ, err = parser.parse(data)

    assert.is_nil(err)
    if environ == nil then
        assert.is_true(false)
        return
    end
    assert.equal("GET", environ.REQUEST_METHOD)
    assert.equal("/", environ.PATH_INFO)
    assert.equal("HTTP/1.1", environ.SERVER_PROTOCOL)
end

-- An invalid request line errors.
function tests.test_invalid_request()
    local data = "invalid"

    local environ, err = parser.parse(data)

    assert.equal(ParserErrors.INVALID_REQUEST_LINE, err)
    assert.is_nil(environ)
end

-- An unsupported version errors.
function tests.test_unsupported_version()
    local data = "GET / HTTP/99\r\n"

    local environ, err = parser.parse(data)

    assert.equal(ParserErrors.VERSION_NOT_SUPPORTED, err)
    assert.is_nil(environ)
end

-- An unsupported method errors.
function tests.test_unsupported_method()
    local data = "INVALID / HTTP/1.1\r\n"

    local environ, err = parser.parse(data)

    assert.equal(ParserErrors.METHOD_NOT_IMPLEMENTED, err)
    assert.is_nil(environ)
end

return tests
