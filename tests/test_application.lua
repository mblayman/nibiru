local assert = require("luassert")
local Application = require("nibiru.application")

local tests = {}

function tests.test_constructor()
    local app = Application()

    assert.equal(getmetatable(app), Application)
end

-- The app behaves like a WSGI callable.
function tests.test_app_is_wsgi_callable()
    local environ = { hello = "world" }
    -- TODO: capture status and response_headers
    local start_response = function(status, response_headers) end
    local app = Application()
    print(app)

    app(environ, start_response)

    -- TODO: assert some stuff.
end

return tests
