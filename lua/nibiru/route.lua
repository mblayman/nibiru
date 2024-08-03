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

local NO_MATCH = 0
local MATCH = 1
local NOT_ALLOWED = 2
--- @alias Match `NO_MATCH` | `MATCH` | `NOT_ALLOWED`

--- @class Route
--- @field path string The path to reach the route
--- @field controller function The controller that will handle the route
--- @field methods Method[] The allowed HTTP methods
local Route = {
    NO_MATCH = NO_MATCH,
    MATCH = MATCH,
    NOT_ALLOWED = NOT_ALLOWED,
}
Route.__index = Route

--- Create a route.
--- @param _ any
--- @param path string The path to reach the route
--- @param controller function The controller that will handle the route
--- @param methods Method[] The allowed HTTP methods
--- @return Route
local function _init(_, path, controller, methods)
    local self = setmetatable({}, Route)
    self.path = path
    self.controller = controller

    -- Use a lookup table for allowed methods for faster checking at runtime.
    if methods then
        local methods_lookup = {}
        for _, method in ipairs(methods) do
            methods_lookup[method] = true
        end
        self.methods = methods_lookup
    else
        self.methods = { GET = true }
    end

    return self
end
setmetatable(Route, { __call = _init })

--- Check if the route matches a method and path.
--- @param method Method
--- @param path string
--- @return Match
function Route.matches(self, method, path)
    -- TODO: check the path against a constructed pattern.

    if self.methods[method] then
        return self.MATCH
    else
        return self.NOT_ALLOWED
    end
end

return Route
