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

--- Validate an unquoted attribute value for malformed syntax.
---@param value string The attribute value to validate
---@return boolean True if valid, false if malformed
---@return string|nil Error message if malformed
local function validate_unquoted_attribute(value)
    -- Check for characters that should not appear in unquoted attributes
    if value:find("[>\"'{}]") then
        return false, "malformed attribute: contains invalid character"
    end
    return true
end

--- Tokenize a statement string (content within {% %} blocks).
---@param input string Statement string to tokenize
---@return table Array of token objects with type and value fields
local function tokenize_stmt(input)
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
            while pos <= len and (is_alnum(input:sub(pos, pos)) or input:sub(pos, pos) == "_") do
                pos = pos + 1
            end
            local word = input:sub(start, pos - 1)

            -- Check for control flow keywords
            if word == "if" then
                table.insert(tokens, {type = "IF_START"})
            elseif word == "endif" then
                table.insert(tokens, {type = "IF_END"})
            elseif word == "for" then
                table.insert(tokens, {type = "FOR_START"})
            elseif word == "endfor" then
                table.insert(tokens, {type = "FOR_END"})
            elseif word == "extends" then
                table.insert(tokens, {type = "EXTENDS"})
            elseif word == "block" then
                table.insert(tokens, {type = "BLOCK_START"})
            elseif word == "endblock" then
                table.insert(tokens, {type = "BLOCK_END"})
            elseif word == "or" or word == "and" or word == "not" or word == "true" or word == "false" or word == "nil" or word == "in" or word == "pairs" or word == "ipairs" then
                -- Logical operators, boolean literals, and for loop keywords
                table.insert(tokens, {type = "KEYWORD", value = word})
            else
                -- Regular identifier
                table.insert(tokens, {type = "IDENTIFIER", value = word})
            end
        elseif c == '"' or c == "'" then
            -- String literal
            local quote = c
            pos = pos + 1
            local start = pos
            while pos <= len and input:sub(pos, pos) ~= quote do
                if input:sub(pos, pos) == "\\" then
                    pos = pos + 1 -- Skip escaped char
                end
                pos = pos + 1
            end
            local str_value = input:sub(start, pos - 1)
            table.insert(tokens, {type = "LITERAL", value = str_value})
            pos = pos + 1 -- Skip closing quote
        elseif c == "." then
            -- Check for .. operator
            if pos + 1 <= len and input:sub(pos + 1, pos + 1) == "." then
                table.insert(tokens, {type = "OPERATOR", value = ".."})
                pos = pos + 2
            else
                table.insert(tokens, {type = "PUNCTUATION", value = "."})
                pos = pos + 1
            end
        elseif c == "=" then
            -- Check for == operator
            if pos + 1 <= len and input:sub(pos + 1, pos + 1) == "=" then
                table.insert(tokens, {type = "OPERATOR", value = "=="})
                pos = pos + 2
            else
                table.insert(tokens, {type = "OPERATOR", value = "="})
                pos = pos + 1
            end
        elseif c == "~" then
            -- Check for ~= operator
            if pos + 1 <= len and input:sub(pos + 1, pos + 1) == "=" then
                table.insert(tokens, {type = "OPERATOR", value = "~="})
                pos = pos + 2
            else
                error("Invalid character '~' in statement at position " .. pos)
            end
        elseif c == ">" then
            if pos + 1 <= len and input:sub(pos + 1, pos + 1) == "=" then
                table.insert(tokens, {type = "OPERATOR", value = ">="})
                pos = pos + 2
            else
                table.insert(tokens, {type = "OPERATOR", value = ">"})
                pos = pos + 1
            end
        elseif c == "<" then
            if pos + 1 <= len and input:sub(pos + 1, pos + 1) == "=" then
                table.insert(tokens, {type = "OPERATOR", value = "<="})
                pos = pos + 2
            else
                table.insert(tokens, {type = "OPERATOR", value = "<"})
                pos = pos + 1
            end
        elseif c == "+" or c == "-" or c == "*" or c == "/" then
            table.insert(tokens, {type = "OPERATOR", value = c})
            pos = pos + 1
        elseif c == "." then
            -- Check for .. operator
            if pos + 1 <= len and input:sub(pos + 1, pos + 1) == "." then
                table.insert(tokens, {type = "OPERATOR", value = ".."})
                pos = pos + 2
            else
                table.insert(tokens, {type = "PUNCTUATION", value = "."})
                pos = pos + 1
            end
        elseif c == "(" or c == ")" or c == "," then
            table.insert(tokens, {type = "PUNCTUATION", value = c})
            pos = pos + 1
        elseif c:match("%d") then
            -- Number literal
            local start = pos
            while pos <= len and input:sub(pos, pos):match("%d") do
                pos = pos + 1
            end
            local num_str = input:sub(start, pos - 1)
            table.insert(tokens, {type = "LITERAL", value = tonumber(num_str)})
        else
            error("Invalid character '" .. c .. "' in statement at position " .. pos)
        end
    end

    return tokens
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
            -- Check if it's a keyword
            if value == "or" or value == "and" or value == "not" or value == "true" or value == "false" or value == "nil" then
                table.insert(tokens, {type = "KEYWORD", value = value})
            else
                table.insert(tokens, {type = "IDENTIFIER", value = value})
            end
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
        elseif c == "|" then
            -- Check for |> pipeline operator
            if pos + 1 <= len and input:sub(pos + 1, pos + 1) == ">" then
                table.insert(tokens, {type = "OPERATOR", value = "|>"})
                pos = pos + 2
            else
                error("Invalid character '|' in expression at position " .. pos)
            end
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
        elseif delimiter_type == "component" then
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

             -- Parse attributes (attr="value", attr='value', or attr=expression)
             local attr_start = #component_name + 1
             local attr_string = tag_content:sub(attr_start):match("^%s*(.-)%s*$")
             if attr_string and attr_string ~= "" then
                 -- Parse individual attributes, handling quoted values with spaces
                 local parsed_attrs = {}
                 local malformed_attrs = {}
                 local pos = 1
                 while pos <= #attr_string do
                     -- Skip whitespace
                     pos = attr_string:find("[^%s]", pos) or (#attr_string + 1)
                     if pos > #attr_string then break end

                     -- Find attr=
                     local attr_start_pos = pos
                     local equal_pos = attr_string:find("=", pos)
                     if not equal_pos then break end

                     local attr = attr_string:sub(attr_start_pos, equal_pos - 1):match("^%s*(.-)%s*$")
                     pos = equal_pos + 1

                     -- Find the value (handle quoted strings)
                     local value
                     if attr_string:sub(pos, pos) == '"' or attr_string:sub(pos, pos) == "'" then
                         -- Quoted string
                         local quote = attr_string:sub(pos, pos)
                         pos = pos + 1
                         local value_start = pos
                         while pos <= #attr_string and attr_string:sub(pos, pos) ~= quote do
                             if attr_string:sub(pos, pos) == "\\" then
                                 pos = pos + 1 -- Skip escaped char
                             end
                             pos = pos + 1
                         end
                         value = attr_string:sub(value_start, pos - 1)
                         pos = pos + 1 -- Skip closing quote
                         parsed_attrs[attr] = { type = "string", value = value }
                      else
                         -- Unquoted expression (until next space or end)
                         local value_start = pos
                         while pos <= #attr_string and attr_string:sub(pos, pos) ~= " " do
                             pos = pos + 1
                         end
                         value = attr_string:sub(value_start, pos - 1)

                         -- Validate unquoted attribute for malformed syntax
                         local is_valid, error_msg = validate_unquoted_attribute(value)
                         if not is_valid then
                             -- Mark as malformed but still include in attributes for now
                             parsed_attrs[attr] = { type = "expression", value = value, malformed = true, error = error_msg }
                             malformed_attrs[attr] = error_msg
                         else
                             parsed_attrs[attr] = { type = "expression", value = value }
                         end
                     end
                 end
                 table.insert(tokens, {type = "COMPONENT_ATTRS", value = parsed_attrs, malformed = malformed_attrs})
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

        elseif delimiter_type == "expr" then
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
        elseif delimiter_type == "stmt" then
            -- Statement start
            table.insert(tokens, {type = "STMT_START"})
            pos = stmt_end_start + 1

            -- Find statement end
            local stmt_end, stmt_end_pos = template_str:find("%%}", pos)
            if not stmt_end then
                error("Unclosed statement starting at position " .. stmt_start)
            end

            -- Tokenize the statement content
            local stmt_content = template_str:sub(pos, stmt_end - 1)
            local stmt_tokens = tokenize_stmt(stmt_content)
            for _, t in ipairs(stmt_tokens) do
                table.insert(tokens, t)
            end

            table.insert(tokens, {type = "STMT_END"})
            pos = stmt_end_pos + 1
        end
    end  -- closes the while loop

    return tokens
end

return Tokenizer