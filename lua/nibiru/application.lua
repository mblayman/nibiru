local Route = require("nibiru.route")

--- @class Application
--- @field routes Route[]
local Application = {}
Application.__index = Application

--- Create an app instance that serves as the WSGI callable.
--- @param _ any
--- @return Application
local function _init(_, routes)
    local self = setmetatable({}, Application)
    self.routes = routes or {}
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

--- Find a matching route for the HTTP request.
--- @param self Application
--- @param method Method The request's HTTP method
--- @param path any The request's path
--- @return Match match Any matching route status from the set of routes
--- @return Route? route A specific route if there is a match
function Application.find_route(self, method, path)
    local match
    for _, route in ipairs(self.routes) do
        match = route:matches(method, path)
        if match ~= Route.NO_MATCH then
            return match, route
        end
    end
    return Route.NO_MATCH, nil
end

return Application
