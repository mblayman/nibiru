local parser = {}

--  HTTP-message   = start-line
--                   *( header-field CRLF )
--                   CRLF
--                   [ message-body ]
--
--  start-line     = request-line / status-line
--
--  request-line = method SP request-target SP HTTP-version CRLF
local REQUEST_LINE_PATTERN = "^(%u+) ([^ ]+) (HTTP/[%d.]+)\r\n"
--
--  request-target = origin-form
--                 / absolute-form
--                 / authority-form
--                 / asterisk-form
--
--  request-target too long, response with 414 URI Too Long
--
--  > Various ad hoc limitations on request-line length are found in practice.
--  > It is RECOMMENDED that all HTTP senders and recipients support, at a minimum,
--  > request-line lengths of 8000 octets.

--- @enum ParserErrors
local ParserErrors = {
    INVALID_REQUEST_LINE = 0,
    VERSION_NOT_SUPPORTED = 1,
    METHOD_NOT_IMPLEMENTED = 2,
}
parser.ParserErrors = ParserErrors

-- Supported HTTP versions
local SUPPORTED_VERSIONS = {
    ["HTTP/1.1"] = true,
}

--- @alias Method
--- | '"GET"'
--- | '"HEAD"'
--- | '"POST"'
--- | '"PUT"'
--- | '"DELETE"'
--- | '"CONNECT"'
--- | '"OPTIONS"'
--- | '"TRACE"'
--- | '"PATCH"'

-- TODO: Validate which of these methods will not be implemented.
-- For now, delegate all HTTP 1.1 methods to the application
-- and let it respond with 405.

-- Supported HTTP methods
local SUPPORTED_METHODS = {
    ["GET"] = true,
    ["HEAD"] = true,
    ["POST"] = true,
    ["PUT"] = true,
    ["DELETE"] = true,
    ["CONNECT"] = true,
    ["OPTIONS"] = true,
    ["TRACE"] = true,
    ["PATCH"] = true,
}

--- Parse the raw HTTP data into a WSGI environ table.
--- @param data string HTTP request data from the network
--- @return table? environ A WSGI environ
--- @return ParserErrors? err A parser error
function parser.parse(data)
    local method, target, version = string.match(data, REQUEST_LINE_PATTERN)
    if not method then
        return nil, ParserErrors.INVALID_REQUEST_LINE
    elseif not SUPPORTED_VERSIONS[version] then
        return nil, ParserErrors.VERSION_NOT_SUPPORTED
    elseif not SUPPORTED_METHODS[method] then
        return nil, ParserErrors.METHOD_NOT_IMPLEMENTED
    end

    local environ = {
        REQUEST_METHOD = method,
        -- This is ignored for now. The nibiru server assumes that it is mounted
        -- at the root of a server rather than some sub-path like /app.
        SCRIPT_NAME = "",
        -- TODO: This version does not parse out the query string.
        PATH_INFO = target,
        -- QUERY_STRING
        -- CONTENT_TYPE
        -- CONTENT_LENGTH
        SERVER_NAME = "localhost",
        SERVER_PORT = "8080",
        SERVER_PROTOCOL = version,
        -- `HTTP_` Variables
        ["wsgi.version"] = { 1, 0 },
        ["wsgi.url_scheme"] = "http",
        -- wsgi.input
        -- wsgi.errors
        ["wsgi.multithread"] = false,
        ["wsgi.multiprocess"] = true,
        ["wsgi.run_once"] = false,
        -- nibiru.example_variable
    }
    return environ, nil
end

return parser
