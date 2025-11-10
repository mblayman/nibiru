-- nibiru/tokenizer.lua
local Tokenizer = {}

--- Check if character is alphabetic.
---@param c string Single character to check
---@return boolean True if alphabetic
local function is_alpha(c)
    return c:match("%a") ~= nil
end

--- Check if character is numeric.
---@param c string Single character to check
---@return boolean True if numeric
local function is_digit(c)
    return c:match("%d") ~= nil
end

--- Check if character is alphanumeric or underscore.
---@param c string Single character to check
---@return boolean True if alphanumeric or underscore
local function is_alnum(c)
    return is_alpha(c) or is_digit(c) or c == "_"
end

--- Tokenize an expression string (content within {{ }} blocks).
---@param input string Expression string to tokenize
---@return table Array of token objects with type and value fields
local function tokenize_expr(input)
    local tokens = {}
    local pos = 1
    local len = #input

    while pos <= len do
        local c = input:sub(pos, pos)

        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            -- Skip whitespace
            pos = pos + 1
        elseif is_alpha(c) then
            -- Identifier or keyword
            local start = pos
            while pos <= len and is_alnum(input:sub(pos, pos)) do
                pos = pos + 1
            end
            local value = input:sub(start, pos - 1)
            table.insert(tokens, {type = "IDENTIFIER", value = value})
        elseif is_digit(c) then
            -- Number literal
            local start = pos
            while pos <= len and (is_digit(input:sub(pos, pos)) or input:sub(pos, pos) == ".") do
                pos = pos + 1
            end
            local value = input:sub(start, pos - 1)
            table.insert(tokens, {type = "LITERAL", value = tonumber(value) or value})
        elseif c == '"' or c == "'" then
            -- String literal
            local quote = c
            pos = pos + 1
            local start = pos
            while pos <= len and input:sub(pos, pos) ~= quote do
                if input:sub(pos, pos) == "\\" then
                    pos = pos + 2  -- Skip escaped char
                else
                    pos = pos + 1
                end
            end
            if pos > len then
                error("Unclosed string literal")
            end
            local value = input:sub(start, pos - 1)
            table.insert(tokens, {type = "LITERAL", value = value})
            pos = pos + 1  -- Skip closing quote
        elseif c == "+" or c == "-" or c == "*" or c == "/" or c == "=" or c == ">" or c == "<" or c == "!" then
            -- Operators
            local start = pos
            pos = pos + 1
            if pos <= len and input:sub(pos, pos) == "=" then
                pos = pos + 1
            end
            local value = input:sub(start, pos - 1)
            table.insert(tokens, {type = "OPERATOR", value = value})
        elseif c == "(" or c == ")" or c == "," or c == "." then
            -- Punctuation
            table.insert(tokens, {type = "PUNCTUATION", value = c})
            pos = pos + 1
        else
            error("Unexpected character in expression: " .. c .. " at position " .. pos)
        end
    end

    return tokens
end

--- Tokenize a template string into tokens for parsing.
--- Supports: TEXT, EXPR_START/EXPR_END, STMT_START/STMT_END, COMPONENT_* tokens
---@param template_str string Template string to tokenize
---@return table Array of token objects with type and optional value fields
function Tokenizer.tokenize(template_str)
    local tokens = {}
    local pos = 1
    local len = #template_str

    while pos <= len do
        local start, end_start = template_str:find("{{", pos)
        local stmt_start, stmt_end_start = template_str:find("{%%", pos)
        local component_start = template_str:find("<[A-Z]", pos)
        local component_close_start = template_str:find("</[A-Z]", pos)

        -- Find the nearest delimiter
        local next_pos
        local delimiter_type
        if component_close_start and (not component_start or component_close_start < component_start) and (not start or component_close_start < start) and (not stmt_start or component_close_start < stmt_start) then
            next_pos = component_close_start
            delimiter_type = "component_close"
        elseif component_start and (not start or component_start < start) and (not stmt_start or component_start < stmt_start) then
            next_pos = component_start
            delimiter_type = "component"
        elseif start and (not stmt_start or start < stmt_start) then
            next_pos = start
            delimiter_type = "expr"
        elseif stmt_start then
            next_pos = stmt_start
            delimiter_type = "stmt"
        else
            next_pos = len + 1
            delimiter_type = "end"
        end

        -- Add TEXT before the delimiter
        if next_pos > pos then
            local text = template_str:sub(pos, next_pos - 1)
            if text ~= "" then
                table.insert(tokens, {type = "TEXT", value = text})
            end
        end

        if delimiter_type == "end" then
            break
        end

        if delimiter_type == "component" then
            -- Parse component opening tag: <ComponentName attr="value" />
            table.insert(tokens, {type = "COMPONENT_START"})
            pos = next_pos + 1

            -- Find component tag end (either /> or >)
            local tag_end = template_str:find("[/>]", pos)
            if not tag_end then
                error("Unclosed component tag starting at position " .. next_pos)
            end

            -- Extract component name and attributes
            local tag_content = template_str:sub(pos, tag_end - 1)
            local component_name = tag_content:match("^([A-Z][A-Za-z0-9_]*)")
            if not component_name then
                error("Invalid component name at position " .. pos)
            end

            table.insert(tokens, {type = "COMPONENT_NAME", value = component_name})

            -- Parse attributes (simplified for now)
            local attr_start = #component_name + 1
            local attributes = tag_content:sub(attr_start):match("^%s*(.-)%s*$")
            if attributes and attributes ~= "" then
                table.insert(tokens, {type = "COMPONENT_ATTRS", value = attributes})
            end

            -- Check if self-closing
            local is_self_closing = template_str:sub(tag_end, tag_end) == "/"
            table.insert(tokens, {type = is_self_closing and "COMPONENT_SELF_CLOSE" or "COMPONENT_OPEN"})

            if is_self_closing then
                -- Skip the />
                pos = tag_end + 2
            else
                -- Skip the >
                pos = tag_end + 1
            end

        elseif delimiter_type == "component_close" then
            -- Parse component closing tag: </ComponentName>
            table.insert(tokens, {type = "COMPONENT_CLOSE"})
            pos = next_pos + 2

            -- Find closing tag end
            local close_end = template_str:find(">", pos)
            if not close_end then
                error("Unclosed component closing tag at position " .. next_pos)
            end

            -- Extract component name
            local tag_content = template_str:sub(pos, close_end - 1)
            local component_name = tag_content:match("^([A-Z][A-Za-z0-9_]*)")
            if not component_name then
                error("Invalid component closing tag at position " .. pos)
            end

            table.insert(tokens, {type = "COMPONENT_NAME", value = component_name})
            pos = close_end + 1

        elseif next_pos == start then
            -- Expression start
            table.insert(tokens, {type = "EXPR_START"})
            pos = end_start + 1

            -- Find expression end
            local expr_end, expr_end_pos = template_str:find("}}", pos)
            if not expr_end then
                error("Unclosed expression starting at position " .. start)
            end

            -- Tokenize the expression content
            local expr_content = template_str:sub(pos, expr_end - 1)
            local expr_tokens = tokenize_expr(expr_content)
            for _, t in ipairs(expr_tokens) do
                table.insert(tokens, t)
            end

            table.insert(tokens, {type = "EXPR_END"})
            pos = expr_end_pos + 1
        elseif next_pos == stmt_start then
            -- Statement start
            table.insert(tokens, {type = "STMT_START"})
            pos = stmt_end_start + 1

            -- Find statement end
            local stmt_end, stmt_end_pos = template_str:find("%%}", pos)
            if not stmt_end then
                error("Unclosed statement starting at position " .. stmt_start)
            end

            -- Tokenize the statement content (similar to expr for now)
            local stmt_content = template_str:sub(pos, stmt_end - 1)
            local stmt_tokens = tokenize_expr(stmt_content)
            for _, t in ipairs(stmt_tokens) do
                table.insert(tokens, t)
            end

            table.insert(tokens, {type = "STMT_END"})
            pos = stmt_end_pos + 1
        end
    end

    return tokens
end

return Tokenizer