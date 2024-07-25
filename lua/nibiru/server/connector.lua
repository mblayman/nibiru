local connector = {}

--- Handle data received on the network connection.
---
--- @param application function The WSGI application callable
--- @param data string The inbound data received on the network connection
--- @return string response The outbound data to send on the connection
function connector.handle_connection(application, data)
    -- TODO: parse inbound data into the environ table
    print(data)
    local environ = {}
    local start_response = function(status, response_headers)
        print(status)
        print(response_headers)
    end

    -- TODO: The application callable returns an iterable. The spec says that
    -- this data should not be buffered and should be sent immediately, but I'm
    -- going to buffer it into a single value to start because it will keep the
    -- exchange with the Lua code and C code easier to begin.
    local response = ""

    -- This code is assuming that application is returning the elements
    -- that would come from a call to ipairs.
    local response_iterator, state, initial = application(environ, start_response)
    -- TODO: Handle start_response data here.

    for _, chunk in response_iterator, state, initial do
        response = response .. chunk
    end
    return response
end

return connector
