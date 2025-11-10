-- nibiru/template.lua
local Template = {}
local Tokenizer = require("nibiru.tokenizer")

--- Component registry: maps component names to their template strings
---@type table<string, string>
local component_registry = {}

--- Register a reusable component template.
---@param name string Component name (should start with capital letter)
---@param template_string string The component's template content
function Template.component(name, template_string)
    if component_registry[name] then
        error("Component '" .. name .. "' is already registered")
    end
    component_registry[name] = template_string
end

--- Escape a string for safe inclusion in Lua double-quoted string literals.
---@param s string String to escape
---@return string Escaped string wrapped in quotes
local function escape_lua_string(s)
    -- Escape for Lua double-quoted string literal
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
    return '"' .. s .. '"'
end

--- Parse an identifier from expression tokens.
---@param parser table Parser state with tokens and pos fields
---@return string The identifier name
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

--- Compile a component template with provided attributes.
---@param component_template string The component's template string
---@param attributes table<string, string> Attribute values to inject into the component
---@return table Array of compiled chunks for the component
local function compile_component(component_template, attributes)
    -- Compile component template with attributes as additional context
    local component_tokens = Tokenizer.tokenize(component_template)
    local component_parser = { tokens = component_tokens, pos = 1 }
    local chunks = {}

    while component_parser.pos <= #component_tokens do
        local token = component_tokens[component_parser.pos]
        if token.type == "TEXT" then
            table.insert(chunks, escape_lua_string(token.value))
            component_parser.pos = component_parser.pos + 1
        elseif token.type == "EXPR_START" then
            component_parser.pos = component_parser.pos + 1
            local var_name = parse_expr(component_parser)
            if component_parser.pos > #component_tokens or component_tokens[component_parser.pos].type ~= "EXPR_END" then
                error("Expected }} after expression in component")
            end
            component_parser.pos = component_parser.pos + 1

            -- Check if this is an attribute, otherwise use normal context access
            if attributes[var_name] then
                table.insert(chunks, escape_lua_string(attributes[var_name]))
            else
                -- Generate Lua code for safe table access and tostring conversion
                table.insert(chunks, string.format('tostring(context[%q] or "")', var_name))
            end
        elseif token.type == "STMT_START" then
            error("Statements not yet supported in components")
        else
            error("Unexpected token in component: " .. token.type .. " at position " .. component_parser.pos)
        end
    end

    return chunks
end

--- Compile a template string into a renderable template object.
---@param template_str string Template string to compile
---@return table Template object with render function and code field
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
        elseif token.type == "COMPONENT_START" then
            -- Parse component usage: <ComponentName attr="value" />
            parser.pos = parser.pos + 1
            if parser.pos > #tokens or tokens[parser.pos].type ~= "COMPONENT_NAME" then
                error("Expected component name after <")
            end
            local component_name = tokens[parser.pos].value
            parser.pos = parser.pos + 1

            -- Check if component is registered
            local component_template = component_registry[component_name]
            if not component_template then
                error("Component '" .. component_name .. "' is not registered")
            end

            -- Parse attributes if present (attr="value" or attr='value')
            local attributes = {}
            if parser.pos <= #tokens and tokens[parser.pos].type == "COMPONENT_ATTRS" then
                local attr_string = tokens[parser.pos].value
                -- Simple attribute parsing: attr="value" or attr='value'
                for attr, value in attr_string:gmatch('([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"') do
                    attributes[attr] = value
                end
                for attr, value in attr_string:gmatch("([a-zA-Z_][a-zA-Z0-9_]*)='([^']*)'") do
                    attributes[attr] = value
                end
                parser.pos = parser.pos + 1
            end

            -- Handle self-closing (/) or opening (>) tag
            local is_self_closing = false
            if parser.pos <= #tokens then
                if tokens[parser.pos].type == "COMPONENT_SELF_CLOSE" then
                    is_self_closing = true
                elseif tokens[parser.pos].type == "COMPONENT_OPEN" then
                    is_self_closing = false
                else
                    error("Expected component tag closure")
                end
                parser.pos = parser.pos + 1
            end

            if is_self_closing then
                -- Inline the component template with attributes as context
                local component_chunks = compile_component(component_template, attributes)
                for _, chunk in ipairs(component_chunks) do
                    table.insert(chunks, chunk)
                end
            else
                -- For now, only support self-closing components
                error("Non-self-closing components not yet supported")
            end

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
