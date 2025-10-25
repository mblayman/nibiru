-- nibiru/template.lua
local Template = {}

local function escape_lua_string(s)
    -- Escape for Lua double-quoted string literal
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
    return '"' .. s .. '"'
end

local function compile(template_str)
    local chunks = {}
    local pos = 1
    local template_len = #template_str

    while pos <= template_len do
        local start, end_start = template_str:find("{{", pos)
        if not start then
            -- No more placeholders, add the remaining static text (if any)
            local remaining = template_str:sub(pos)
            if remaining ~= "" then
                table.insert(chunks, escape_lua_string(remaining))
            end
            break
        end

        -- Add static text before the placeholder (if any)
        local static = template_str:sub(pos, start - 1)
        if static ~= "" then
            table.insert(chunks, escape_lua_string(static))
        end

        -- Find the end of the placeholder
        local var_end, end_pos = template_str:find("}}", end_start + 1)
        if not var_end then
            error("Unclosed placeholder starting at position " .. start)
        end

        -- Extract the variable name (trim whitespace for simplicity)
        local var_name =
            template_str:sub(end_start + 1, var_end - 1):match("^%s*(.-)%s*$")
        if var_name == "" then
            error("Empty placeholder at position " .. start)
        end

        -- Generate Lua code for safe table access and tostring conversion
        table.insert(chunks, string.format('tostring(context[%q] or "")', var_name))

        -- Move position past the closing }}
        pos = end_pos + 1
    end

    -- If no chunks, just empty string
    if #chunks == 0 then
        return function()
            return ""
        end
    end

    -- Build the function body
    local body = "local context = ...\nreturn " .. table.concat(chunks, " .. ")
    local chunk, load_err = load(body)
    if not chunk then
        error("Failed to compile template: " .. load_err)
    end

    -- Return a render function that takes context and calls the compiled chunk
    return function(context)
        -- Wrap context in a table if not already
        local ctx = type(context) == "table" and context or {}
        return chunk(ctx)
    end
end

-- Make the Template constructor callable: Template(template_str) returns the render function directly
setmetatable(Template, {
    __call = function(_, template_str)
        if type(template_str) ~= "string" then
            error("Template string must be a string")
        end
        return compile(template_str)
    end,
})

return Template
