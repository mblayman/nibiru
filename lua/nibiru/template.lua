-- nibiru/template.lua
local Template = {}
local Tokenizer = require("nibiru.tokenizer")

local function escape_lua_string(s)
    -- Escape for Lua double-quoted string literal
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
    return '"' .. s .. '"'
end

local function parse_expr(parser)
    local tokens = parser.tokens
    local token = tokens[parser.pos]
    if token.type == "IDENTIFIER" then
        parser.pos = parser.pos + 1
        return token.value
    else
        error("Expected identifier in expression at position " .. parser.pos)
    end
end

local function compile(template_str)
    local tokens = Tokenizer.tokenize(template_str)
    local parser = { tokens = tokens, pos = 1 }
    local chunks = {}

    while parser.pos <= #tokens do
        local token = tokens[parser.pos]
        if token.type == "TEXT" then
            table.insert(chunks, escape_lua_string(token.value))
            parser.pos = parser.pos + 1
        elseif token.type == "EXPR_START" then
            parser.pos = parser.pos + 1
            local var_name = parse_expr(parser)
            if parser.pos > #tokens or tokens[parser.pos].type ~= "EXPR_END" then
                error("Expected }} after expression")
            end
            parser.pos = parser.pos + 1
            -- Generate Lua code for safe table access and tostring conversion
            table.insert(chunks, string.format('tostring(context[%q] or "")', var_name))
        elseif token.type == "STMT_START" then
            error("Statements not yet supported")
        else
            error("Unexpected token: " .. token.type .. " at position " .. parser.pos)
        end
    end

    -- If no chunks, just empty string
    if #chunks == 0 then
        return function()
            return ""
        end
    end

    -- Build the function body using a table for efficient concatenation
    local body = "local context = ...\nlocal parts = {}\n"
    for _, chunk in ipairs(chunks) do
        body = body .. "table.insert(parts, " .. chunk .. ")\n"
    end
    body = body .. "return table.concat(parts)"
    local chunk, load_err = load(body)
    if not chunk then
        error("Failed to compile template: " .. load_err)
    end

    -- Format the body for pretty printing
    local formatted_body = "local context = ...\n\nlocal parts = {}\n"
    for _, chunk in ipairs(chunks) do
        formatted_body = formatted_body .. "table.insert(parts, " .. chunk .. ")\n"
    end
    formatted_body = formatted_body .. "\nreturn table.concat(parts)"

    -- Return a table with render function and the formatted code
    local result = {
        render = function(context)
            -- Wrap context in a table if not already
            local ctx = type(context) == "table" and context or {}
            return chunk(ctx)
        end,
        code = formatted_body,
    }
    -- Make the table callable for backward compatibility
    setmetatable(result, {
        __call = function(self, context)
            return self.render(context)
        end,
    })
    return result
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
