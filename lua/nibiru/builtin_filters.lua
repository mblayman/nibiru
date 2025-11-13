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

--- Convert a string to lowercase
---@param value any Value to convert (should be string)
---@return string Lowercase version of the input
local function lowercase(value)
    if type(value) ~= "string" then
        error("lowercase filter expects a string, got " .. type(value))
    end
    return string.lower(value)
end

-- Return table mapping filter names to functions
return {
    uppercase = uppercase,
    lowercase = lowercase,
}