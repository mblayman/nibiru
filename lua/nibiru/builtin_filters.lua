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

-- Return table mapping filter names to functions
return {
    uppercase = uppercase,
}