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

--- Capitalize the first letter of each word in a string
---@param value any Value to convert (should be string)
---@return string Capitalized version of the input
local function capitalize(value)
    if type(value) ~= "string" then
        error("capitalize filter expects a string, got " .. type(value))
    end
    -- Capitalize first letter of each word (separated by whitespace)
    return (value:gsub("(%w+)", function(word)
        return string.upper(word:sub(1, 1)) .. string.lower(word:sub(2))
    end))
end

--- Truncate a string to a specified length
---@param value any Value to truncate (should be string)
---@param length number Maximum length (should be positive integer)
---@return string Truncated version of the input
local function truncate(value, length)
    if type(value) ~= "string" then
        error("truncate filter expects a string, got " .. type(value))
    end
    if type(length) ~= "number" or length < 0 or length ~= math.floor(length) then
        error("truncate filter expects a positive integer length, got " .. tostring(length))
    end
    if #value <= length then
        return value
    end
    return value:sub(1, length)
end

--- Get the length of a string, array, or table
---@param value any Value to get length of
---@return number Length of the input
local function length(value)
    local t = type(value)
    if t == "string" then
        return #value
    elseif t == "table" then
        -- For arrays, return #value (sequence length)
        -- For hash tables, count the number of keys
        local count = 0
        for _ in pairs(value) do
            count = count + 1
        end
        return count
    else
        error("length filter expects a string or table, got " .. t)
    end
end

--- Get the first element of an array or first character of a string
---@param value any Value to get first element from
---@return any First element or character
local function first(value)
    local t = type(value)
    if t == "string" then
        if #value == 0 then
            return ""
        end
        return value:sub(1, 1)
    elseif t == "table" then
        -- For arrays, return the first element (index 1)
        return value[1]
    else
        error("first filter expects a string or table, got " .. t)
    end
end

--- Get the last element of an array or last character of a string
---@param value any Value to get last element from
---@return any Last element or character
local function last(value)
    local t = type(value)
    if t == "string" then
        if #value == 0 then
            return ""
        end
        return value:sub(-1)  -- Last character
    elseif t == "table" then
        -- For arrays, find the highest numeric index
        local max_index = 0
        for k, _ in pairs(value) do
            if type(k) == "number" and k > max_index and k == math.floor(k) then
                max_index = k
            end
        end
        return value[max_index]
    else
        error("last filter expects a string or table, got " .. t)
    end
end

-- Return table mapping filter names to functions
return {
    uppercase = uppercase,
    lowercase = lowercase,
    capitalize = capitalize,
    truncate = truncate,
    length = length,
    first = first,
    last = last,
}