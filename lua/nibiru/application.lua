--- @class Application
local Application = {}
Application.__index = Application

--- Create an app instance that serves as the WSGI callable.
--- @param _ any
--- @return Application
local function _init(_)
    local self = setmetatable({}, Application)
    return self
end
setmetatable(Application, { __call = _init })

--- Handle requests from a server, according to the WSGI interface.
--- @param self Application
--- @param environ table The input request data
--- @param start_response function The callable to invoke before returning data
function Application.__call(self, environ, start_response)
    start_response("200 OK", {})
    return ipairs({ "hello world" })
end

return Application
