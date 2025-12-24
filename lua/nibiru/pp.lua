local function pp(t, indent, visited, output)
    indent = indent or ""
    visited = visited or {}
    output = output or {}

    if type(t) ~= "table" then
        table.insert(output, indent .. tostring(t) .. "\n")
        return
    end

    if visited[t] then
        table.insert(output, indent .. "<circular reference>\n")
        return
    end

    visited[t] = true

    table.insert(output, indent .. "{\n")
    local next_indent = indent .. "    "

    for k, v in pairs(t) do
        local key_str
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            key_str = next_indent .. k .. " = "
        else
            key_str = next_indent .. "[" .. tostring(k) .. "] = "
        end

        if type(v) == "table" then
            table.insert(output, key_str .. "\n")
            pp(v, next_indent, visited, output)
        else
            table.insert(output, key_str .. tostring(v) .. "\n")
        end
    end

    table.insert(output, indent .. "}\n")

    visited[t] = nil
end

--- Pretty prints a Lua table to stdout and returns the formatted string.
--- Handles nested tables with proper indentation and detects circular references.
---@param t any The value to pretty print (table or other types)
---@return string The formatted string representation of the value
local function pretty_print(t)
    local output = {}
    pp(t, "", {}, output)
    local result = table.concat(output)
    io.write(result)
    return result
end

return pretty_print