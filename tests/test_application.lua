local assert = require("luassert")
local Application = require("nibiru.application")

local tests = {}

function tests.test_constructor()
    local app = Application()

    assert.equal(Application, getmetatable(app))
end

-- The app behaves like a WSGI callable.
function tests.test_app_is_wsgi_callable()
    local start_response_called = false
    local actual_status = ""
    local actual_response_headers = nil
    local environ = { hello = "world" }
    local start_response = function(status, response_headers)
        start_response_called = true
        actual_status = status
        actual_response_headers = response_headers
    end
    local app = Application()

    app(environ, start_response)

    assert.is_true(start_response_called)
    assert.equal("200 OK", actual_status)
    assert.same({}, actual_response_headers)
end

return tests
