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
    -- When I do get to this level, it appears that the way to handle the
    -- Content-Length for iterables is to use `Transfer-Encoding: chunked`
    -- which doesn't require a known content length.
    local response = ""

    -- This code is assuming that application is returning the elements
    -- that would come from a call to ipairs.
    local response_iterator, state, initial = application(environ, start_response)
    -- TODO: Handle start_response data here.
    -- To avoid creating a closure function with every request, start_response
    -- could be a function attached to the module and write to module state.
    -- This would prevent start_response from being reentrant, but since I'm
    -- designing this module to only be called by a single process at a time,
    -- that should be fine.

    -- TODO: if the application doesn't provide Content-Length, then special
    -- code will be needed to tack on that header before appending the content
    -- from the response iterator. This will be impossible to calculate
    -- without buffering the response.

    for _, chunk in response_iterator, state, initial do
        response = response .. chunk
    end
    return response
end

return connector
