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

-- Converter type is not optional!
local PARAMETER_PATTERN = "<([a-zA-Z_][a-zA-Z0-9_]*)(:[a-zA-Z_][a-zA-Z0-9_]*)>"

local CONVERTER_PATTERNS = {
    -- string should include any character except a slash.
    string = "([^/]+)",
    integer = "([%d]+)",
}
local CONVERTER_TRANSFORMS = { integer = math.tointeger }

--- Make a pattern that corresponds to path.
---
--- If the path includes parameters, then converters are returned in the table
--- which will be used later to construct arguments to the controller that is
--- associated with the Route.
--- @param path string The desired routing path
--- @return string pattern The string pattern used for matching
--- @return table converters Converters for each parameter in the pattern
local function make_path_matcher(path)
    assert(path:sub(1, 1) == "/", "A route path must start with a slash `/`.")

    -- Capture which converters are used. There will be one converter for each parameter.
    local converters = {}

    local pattern = "^"
    local index, path_length = 1, string.len(path)
    local parameter_start, parameter_end
    while index <= path_length do
        parameter_start, parameter_end = string.find(path, PARAMETER_PATTERN, index)
        if parameter_start then
            -- Include any literal characters before the parameter.
            pattern = pattern .. string.sub(path, index, parameter_start - 1)

            local _, converter = string.match(path, PARAMETER_PATTERN, parameter_start)
            local converter_type = string.sub(converter, 2) -- strip off the colon

            local converter_pattern = CONVERTER_PATTERNS[converter_type]
            if not converter_pattern then
                error("Unknown converter type: " .. converter_type)
            end

            pattern = pattern .. converter_pattern
            table.insert(converters, converter_type)
            index = parameter_end + 1
        else
            -- No parameters. Capture any remaining portion.
            pattern = pattern .. string.sub(path, index)
            break
        end
    end
    return pattern .. "$", converters
end

--- @class Route
--- @field path string The path to reach the route
--- @field path_pattern string The string pattern corresponding to the path
--- @field converters table Converters for parameters in the path
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
    self.path_pattern, self.converters = make_path_matcher(path)
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
--- @param method Method The HTTP method in the request
--- @param path string The path of the request
--- @return Match
function Route.matches(self, method, path)
    if not string.match(path, self.path_pattern) then
        return NO_MATCH
    end

    if self.methods[method] then
        return MATCH
    else
        return NOT_ALLOWED
    end
end

---Run a route by preparing parameters and invoking the controller.
---@param self Route
---@param request Request
---@return Response
function Route.run(self, request)
    local raw_parameters = table.pack(string.match(request.path, self.path_pattern))

    local transformer
    local parameters = {}
    for i, converter_type in ipairs(self.converters) do
        transformer = CONVERTER_TRANSFORMS[converter_type]
        if transformer then
            table.insert(parameters, transformer(raw_parameters[i]))
        else
            table.insert(parameters, raw_parameters[i])
        end
    end

    return self.controller(request, table.unpack(parameters))
end

return Route
