local http = {}

--- @class Response
--- @field status_code integer The status code
--- @field content string HTTP response body data
--- @field content_type string MIME type of response data
--- @field headers table Storage for the response headers
local Response = {}
Response.__index = Response

--- An HTTP response
---
--- The response object is the primary output interface for controllers.
---
--- @param status_code integer
--- @param content string
--- @param content_type string
--- @param headers table
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
--- @param content string
--- @param content_type string
--- @param headers table
--- @return Response
function http.ok(content, content_type, headers)
    return Response(200, content, content_type, headers)
end

return http
