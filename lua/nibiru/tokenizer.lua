-- nibiru/tokenizer.lua
local Tokenizer = {}

local function is_alpha(c)
    return c:match("%a") ~= nil
end

local function is_digit(c)
    return c:match("%d") ~= nil
end

local function is_alnum(c)
    return is_alpha(c) or is_digit(c) or c == "_"
end

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

function Tokenizer.tokenize(template_str)
    local tokens = {}
    local pos = 1
    local len = #template_str

    while pos <= len do
        local start, end_start = template_str:find("{{", pos)
        local stmt_start, stmt_end_start = template_str:find("{%%", pos)

        -- Find the nearest delimiter
        local next_pos
        if start and (not stmt_start or start < stmt_start) then
            next_pos = start
        elseif stmt_start then
            next_pos = stmt_start
        else
            next_pos = len + 1
        end

        -- Add TEXT before the delimiter
        if next_pos > pos then
            local text = template_str:sub(pos, next_pos - 1)
            if text ~= "" then
                table.insert(tokens, {type = "TEXT", value = text})
            end
        end

        if not start and not stmt_start then
            break
        end

        if next_pos == start then
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