--- Bootstrap the system by generating the WSGI callable used with connection
--- handling.
---
--- @param app_module string The requireable module name containing the app
--- @param app_name string The name of the app callable within the module
local function bootstrap(app_module, app_name)
    print("In Lua: " .. app_module .. " " .. app_name)

    -- TODO: load the framework's app.
    -- TODO: This should probably switch to just using the loaded application.
    -- Let the framework side handle any middleware stuff.
    -- bootstrapping should be as dumb as possible.
    -- TODO: application needs to call start_response

    return function(environ, start_response)
        print("In Lua application function")
        -- TODO: switch this to using an iterable table of data
        return "HTTP/1.1 200 OK\r\n\r\n"
    end
end

return { bootstrap = bootstrap }
