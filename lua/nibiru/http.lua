local http = {}

--- @class Request
--- @field method Method
--- @field path string HTTP request path
local Request = {}
Request.__index = Request

--- An HTTP request
---
--- The request object is the primary input interface for responders.
---
--- @param method? Method
--- @param path? string HTTP request path
--- @return Request
local function _init(_, method, path)
    local self = setmetatable({}, Request)

    self.method = method or "GET"
    self.path = path or ""

    return self
end
setmetatable(Request, { __call = _init })
http.Request = Request

--- Create a GET request.
--- @param path? string HTTP request path
--- @return Request
function http.get(path)
    return Request("GET", path)
end

--- @class Response
--- @field status_code integer The status code
--- @field content string HTTP response body data
--- @field content_type string MIME type of response data
--- @field headers table Storage for the response headers
local Response = {}
Response.__index = Response

--- An HTTP response
---
--- The response object is the primary output interface for responders.
---
--- @param status_code? integer
--- @param content? string
--- @param content_type? string
--- @param headers? table
--- @return Response
local function _init(_, status_code, content, content_type, headers)
    local self = setmetatable({}, Response)

    self.status_code = status_code or 200
    self.content = content or ""
    self.content_type = content_type or "text/html"
    self.headers = headers or {}

    return self
end
setmetatable(Response, { __call = _init })
http.Response = Response

--- Create a 200 OK response.
--- @param content? string
--- @param content_type? string
--- @param headers? table
--- @return Response
function http.ok(content, content_type, headers)
    return Response(200, content, content_type, headers)
end

--- Create a 404 Not Found response.
--- @param content? string
--- @param content_type? string
--- @param headers? table
--- @return Response
function http.not_found(content, content_type, headers)
    content = content or "Not Found"
    content_type = content_type or "text/html"
    return Response(404, content, content_type, headers)
end

--- Create a 405 Not Found response.
--- @param content? string
--- @param content_type? string
--- @param headers? table
--- @return Response
function http.method_not_allowed(content, content_type, headers)
    content = content or "Method Not Allowed"
    content_type = content_type or "text/html"
    return Response(405, content, content_type, headers)
end

-- A map of numeric status codes to string representations
http.statuses = {
    -- 1xx - https://httpwg.org/specs/rfc7231.html#status.1xx
    [100] = "100 Continue",
    [101] = "101 Switching Protocols",
    -- 2xx - https://httpwg.org/specs/rfc7231.html#status.2xx
    [200] = "200 OK",
    [201] = "201 Created",
    [202] = "202 Accepted",
    [203] = "203 Non-Authoritative Information",
    [204] = "204 No Content",
    [205] = "205 Reset Content",
    [206] = "206 Partial Content", -- RFC7233
    -- 3xx - https://httpwg.org/specs/rfc7231.html#status.3xx
    [300] = "300 Multiple Choices",
    [301] = "301 Moved Permanently",
    [302] = "302 Found",
    [303] = "303 See Other",
    [304] = "304 Not Modified", -- RFC7232
    [305] = "305 Use Proxy",
    [306] = "306 (Unused)",
    [307] = "307 Temporary Redirect",
    -- 4xx - https://httpwg.org/specs/rfc7231.html#status.4xx
    [400] = "400 Bad Request",
    [401] = "401 Unauthorized", -- RFC7235
    [402] = "402 Payment Required",
    [403] = "403 Forbidden",
    [404] = "404 Not Found",
    [405] = "405 Method Not Allowed",
    [406] = "406 Not Acceptable",
    [407] = "407 Proxy Authentication Required", -- RFC7235
    [408] = "408 Request Timeout",
    [409] = "409 Conflict",
    [410] = "410 Gone",
    [411] = "411 Length Required",
    [412] = "412 Precondition Failed", -- RFC7232
    [413] = "413 Payload Too Large",
    [414] = "414 URI Too Long",
    [415] = "415 Unsupported Media Type",
    [416] = "416 Range Not Satisfiable", -- RFC7233
    [417] = "417 Expectation Failed",
    [426] = "426 Upgrade Required",
    -- 5xx - https://httpwg.org/specs/rfc7231.html#status.5xx
    [500] = "500 Internal Server Error",
    [501] = "501 Not Implemented",
    [502] = "502 Bad Gateway",
    [503] = "503 Service Unavailable",
    [504] = "504 Gateway Timeout",
    [505] = "505 HTTP Version Not Supported",
}

return http
