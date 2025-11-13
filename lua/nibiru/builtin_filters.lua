-- nibiru/builtin_filters.lua

-- String filters

--- Convert a string to uppercase
---@param value any Value to convert (should be string)
---@return string Uppercase version of the input
local function uppercase(value)
    if type(value) ~= "string" then
        error("uppercase filter expects a string, got " .. type(value))
    end
    return string.upper(value)
end

--- Register all built-in filters with the Template module
---@param Template table The Template module
local function register_builtin_filters(Template)
    Template.register_filter("uppercase", uppercase)
end

return {
    uppercase = uppercase,
    register = register_builtin_filters,
}