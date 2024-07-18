-- TODO: This should probably switch to just using the loaded application.
-- Let the framework side handle any middleware stuff.
-- bootstrapping should be as dumb as possible.
-- TODO: application needs to call start_response
-- TODO: switch this to using an iterable table of data
local function app(environ, start_response)
    print("In Lua application function")
    return ipairs({ "HTTP/1.1 ", "200 OK", "\r\n\r\n" })
end

return { app = app }
