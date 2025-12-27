local http = require("nibiru.http")
local Route = require("nibiru.route")
local Config = require("nibiru.config")
local TemplateLoader = require("nibiru.loader")

local not_found = http.not_found()
local method_not_allowed = http.method_not_allowed()

--- @class Application
--- @field routes Route[]
--- @field routes_by_name table<string, Route> Lookup table for routes by name
--- @field config table Configuration loaded from config.lua
--- @field app Application An alias for the application
local Application = {}
Application.__index = Application

--- Create an app instance that serves as the WSGI callable.
--- @param _ any
--- @param routes Route[]? Routes to add to the application
--- @param config_path string? Optional path to config file
--- @return Application
local function _init(_, routes, config_path)
    local self = setmetatable({}, Application)
    self.routes = routes or {}
    self.routes_by_name = {}

    -- Process routes and build name lookup table
    for _, route in ipairs(self.routes) do
        if route.name then
            if self.routes_by_name[route.name] then
                error("Duplicate route name: " .. route.name)
            end
            self.routes_by_name[route.name] = route
        end
    end

    -- Determine config path if not provided
    if not config_path then
        -- Read from boot parameters to determine config location
        local boot_params = require("nibiru.boot_parameters")
        if boot_params.app_module then
            -- Convert module name to config path
            -- e.g., "docs.app" -> "docs/config.lua"
            config_path = boot_params.app_module:gsub("%.", "/") .. ".lua"
            config_path = config_path:gsub("/[^/]+$", "/config.lua")
        end
    end

    -- Load configuration from the determined path
    self.config = Config.load(config_path)

    -- Initialize template loader using configured directory
    TemplateLoader.from_directory(self.config.templates.directory)

    -- By keeping a reference to itself as `app`, a real project can simplify
    -- how it provides the nibiru server with the application instance.
    self.app = self

    return self
end
setmetatable(Application, { __call = _init })

--- Handle requests from a server, according to the WSGI interface.
--- @param self Application
--- @param environ table The input request data
--- @param start_response function The callable to invoke before returning data
function Application.__call(self, environ, start_response)
    local match, route = self:find_route(environ.REQUEST_METHOD, environ.PATH_INFO)

    local response = not_found
    if match == Route.MATCH and route then
        local request = http.Request(environ.REQUEST_METHOD, environ.PATH_INFO)
        response = route:run(request)
    elseif match == Route.NOT_ALLOWED then
        response = method_not_allowed
    end

    -- TODO: handle an unknown status
    local status = http.statuses[response.status_code]

    -- TODO: handle response headers
    start_response(status, {})
    return ipairs({ response.content })
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

--- Generate a URL by looking up a named route and delegating to its url_for method.
--- @param self Application
--- @param route_name string The name of the route to generate URL for
--- @param ... any Parameters to pass to the route's url_for method
--- @return string The generated URL path
function Application.url_for(self, route_name, ...)
    local route = self.routes_by_name[route_name]
    if not route then
        error(string.format("Unknown route name: %s", route_name))
    end

    return route:url_for(...)
end

return Application
