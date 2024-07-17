local connector = {}

--- Handle data received on the network connection.
---
--- @param application function The WSGI application callable
--- @param data string The inbound data received on the network connection
--- @return string response The outbound data to send on the connection
function connector.handle_connection(application, data)
    -- TODO: parse inbound data into the environ table

    -- TODO: The application callable returns an iterable. The spec says that
    -- this data should not be buffered and should be sent immediately, but I'm
    -- going to buffer it into a single value to start because it will keep the
    -- exchange with the Lua code and C code easier to begin.

    -- TODO: handle the iterable aspect
    -- TODO: pass the right arguments to application
    return application() .. data
end

return connector
