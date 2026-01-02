local parser = require("nibiru.server.http_parser")
local ParserErrors = parser.ParserErrors

--- @class connector
--- @field status string HTTP status with Status-Code and Reason-Phrase
--- @field response_headers table Storage for the response headers
local connector = {
    status = "",
    response_headers = {},
}

--- Record information about the response.
---
--- This is the callable passed to the WSGI application. It is connected
--- to the module to avoid creating a closure for every request.
--- This design prevents start_response from being reentrant, but since I'm
--- designing this module to only be called by a single process at a time,
--- that should be fine.
--- @param status string HTTP status like "200 OK" or "404 Not Found"
--- @param response_headers table Any response headers
function connector.start_response(status, response_headers)
    connector.status = status
    connector.response_headers = response_headers
end

--- Handle data received on the network connection.
---
--- @param application function The WSGI application callable
--- @param method string The HTTP method
--- @param target string The request target/path
--- @param version string The HTTP version
--- @param remaining_data string The remaining HTTP data after the request line
--- @return string response The outbound data to send on the connection
function connector.handle_connection(application, method, target, version, remaining_data)
    local environ, err = parser.parse(method, target, version, remaining_data)

    -- Note: Error handling for invalid request lines is now done in C

    -- TODO: The application callable returns an iterable. The spec says that
    -- this data should not be buffered and should be sent immediately, but I'm
    -- going to buffer it into a single value to start because it will keep the
    -- exchange with the Lua code and C code easier to begin.
    -- When I do get to this level, it appears that the way to handle the
    -- Content-Length for iterables is to use `Transfer-Encoding: chunked`
    -- which doesn't require a known content length.

    -- This code is assuming that application is returning the elements
    -- that would come from a call to ipairs.
    local response_iterator, state, initial =
        application(environ, connector.start_response)

    local response = { "HTTP/1.1 ", connector.status, "\r\n" }

    -- TODO: handle response_headers serialization
    table.insert(response, "\r\n")

    -- TODO: if the application doesn't provide Content-Length, then special
    -- code will be needed to tack on that header before appending the content
    -- from the response iterator. This will be impossible to calculate
    -- without buffering the response.

    for _, chunk in response_iterator, state, initial do
        table.insert(response, chunk)
    end
    return table.concat(response)
end

return connector
