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

--- @class Route
--- @field path string The path to reach the route
--- @field controller function The controller that will handle the route
--- @field methods Method[] The allowed HTTP methods
local Route = {}
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
    self.methods = methods or { "GET" }
    return self
end

setmetatable(Route, { __call = _init })

return Route
