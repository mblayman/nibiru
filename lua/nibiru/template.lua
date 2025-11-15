-- nibiru/template.lua

local builtin_filters = require("nibiru.builtin_filters")
local Tokenizer = require("nibiru.tokenizer")

local Template = {}

--- Component registry: maps component names to their template strings
---@type table<string, string>
local component_registry = {}

--- Filter registry: maps filter names to their functions
---@type table<string, function>
local filter_registry = {}

--- Template registry: maps template names to their template strings
---@type table<string, string>
local template_registry = {}

--- Set of template names currently being processed (to detect cycles)
---@type table<string, boolean>
local processing_templates = {}

--- Register a reusable component template.
---@param name string Component name (should start with capital letter)
---@param template_string string The component's template content
function Template.component(name, template_string)
    if not name:match("^[A-Z]") then
        error("component names must start with capital")
    end
    if component_registry[name] then
        error("Component '" .. name .. "' is already registered")
    end
    component_registry[name] = template_string
end

--- Clear all registered components (for testing).
function Template.clear_components()
    component_registry = {}
end

--- Register a filter function.
---@param name string Filter name
---@param filter_func function Filter function
function Template.register_filter(name, filter_func)
    if filter_registry[name] then
        error("Filter '" .. name .. "' is already registered")
    end
    if type(filter_func) ~= "function" then
        error("Filter '" .. name .. "' must be a function")
    end
    filter_registry[name] = filter_func
end

--- Clear all registered filters (for testing).
function Template.clear_filters()
    filter_registry = {}
end

--- Register a named template for inheritance.
---@param name string Template name (should be a valid identifier)
---@param template_string string The template content
function Template.register(name, template_string)
    if not name or name == "" then
        error("Template name cannot be empty")
    end
    if template_registry[name] then
        error("Template '" .. name .. "' is already registered")
    end
    template_registry[name] = template_string
end

--- Clear all registered templates (for testing).
function Template.clear_templates()
    template_registry = {}
end

--- Escape a string for safe inclusion in Lua double-quoted string literals.
---@param s string String to escape
---@return string Escaped string wrapped in quotes
local function escape_lua_string(s)
    -- Escape for Lua double-quoted string literal
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
    return '"' .. s .. '"'
end

--- Parse a filter pipeline expression and generate Lua code.
---@param expr_tokens table Array of expression tokens
---@param attributes table<string, any> Optional attributes table for component context
---@return string Lua code that evaluates the filter pipeline
local function parse_filter_pipeline(expr_tokens, attributes)
    -- Simple implementation for basic filter support
    -- Look for |> operators and convert to function calls

    local parts = {}
    local i = 1
    local current_expr = {}

    while i <= #expr_tokens do
        local token = expr_tokens[i]

        if token.type == "OPERATOR" and token.value == "|>" then
            -- Found a filter pipeline operator
            -- The current_expr contains the value to filter
            -- The next tokens should be the filter name and arguments

            if #current_expr == 0 then
                error("Expected expression before |> operator")
            end

            -- Parse filter name
            i = i + 1
            if i > #expr_tokens or expr_tokens[i].type ~= "IDENTIFIER" then
                error("Expected filter name after |> operator")
            end
            local filter_name = expr_tokens[i].value

            -- Check if filter exists
            if not filter_registry[filter_name] then
                error("Unknown filter '" .. filter_name .. "'")
            end

            -- Parse optional arguments
            local args = {}
            i = i + 1
            if
                i <= #expr_tokens
                and expr_tokens[i].type == "PUNCTUATION"
                and expr_tokens[i].value == "("
            then
                -- Parse arguments until closing )
                i = i + 1
                local current_arg = {}
                while
                    i <= #expr_tokens
                    and not (
                        expr_tokens[i].type == "PUNCTUATION"
                        and expr_tokens[i].value == ")"
                    )
                do
                    if
                        expr_tokens[i].type == "PUNCTUATION"
                        and expr_tokens[i].value == ","
                    then
                        -- End of current argument
                        if #current_arg > 0 then
                            table.insert(args, table.concat(current_arg))
                            current_arg = {}
                        end
                    else
                        -- Add token to current argument
                        if expr_tokens[i].type == "IDENTIFIER" then
                            -- Check if this is an attribute (for component context)
                            if attributes and attributes[expr_tokens[i].value] then
                                -- Attributes may be strings or Lua code marked with __CODE__
                                local attr_value = attributes[expr_tokens[i].value]
                                if
                                    type(attr_value) == "string"
                                    and attr_value:sub(1, 8) == "__CODE__"
                                then
                                    -- This is Lua code, insert it directly
                                    table.insert(
                                        current_arg,
                                        "(" .. attr_value:sub(9) .. ")"
                                    )
                                else
                                    -- String literal
                                    table.insert(
                                        current_arg,
                                        escape_lua_string(attr_value)
                                    )
                                end
                            else
                                table.insert(current_arg, "c." .. expr_tokens[i].value)
                            end
                        elseif expr_tokens[i].type == "LITERAL" then
                            if type(expr_tokens[i].value) == "string" then
                                table.insert(
                                    current_arg,
                                    string.format("%q", expr_tokens[i].value)
                                )
                            else
                                table.insert(
                                    current_arg,
                                    tostring(expr_tokens[i].value)
                                )
                            end
                        else
                            table.insert(current_arg, expr_tokens[i].value or "")
                        end
                    end
                    i = i + 1
                end
                -- Add the last argument if any
                if #current_arg > 0 then
                    table.insert(args, table.concat(current_arg))
                end
                if i > #expr_tokens or expr_tokens[i].value ~= ")" then
                    error("Expected closing ) after filter arguments")
                end
                i = i + 1
            end

            -- Generate filter call
            local value_expr = table.concat(current_expr)
            local args_str = #args > 0 and ", " .. table.concat(args, ", ") or ""
            local filter_call =
                string.format("fr[%q](%s%s)", filter_name, value_expr, args_str)

            -- Reset for next part of pipeline
            current_expr = { filter_call }
        else
            -- Regular token, add to current expression
            if token.type == "IDENTIFIER" then
                -- Check if this is an attribute (for component context)
                if attributes and attributes[token.value] then
                    -- Attributes may be strings or Lua code marked with __CODE__
                    local attr_value = attributes[token.value]
                    if
                        type(attr_value) == "string"
                        and attr_value:sub(1, 8) == "__CODE__"
                    then
                        -- This is Lua code, insert it directly
                        table.insert(current_expr, "(" .. attr_value:sub(9) .. ")")
                    else
                        -- String literal
                        table.insert(current_expr, escape_lua_string(attr_value))
                    end
                else
                    table.insert(current_expr, "c." .. token.value)
                end
            elseif token.type == "LITERAL" then
                if type(token.value) == "string" then
                    table.insert(current_expr, string.format("%q", token.value))
                else
                    table.insert(current_expr, tostring(token.value))
                end
            else
                table.insert(current_expr, token.value or "")
            end
            i = i + 1
        end
    end

    return table.concat(current_expr)
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

--- Evaluate an attribute value that may contain expressions
---@param value string Raw attribute value that may contain {{expressions}}
---@param parser table Current parser state for error reporting
---@return string Lua code that evaluates to the attribute value at render time
local function evaluate_attribute_value(value, parser)
    -- If the value contains expressions, we need to generate code to evaluate them
    -- For now, handle simple case of entire value being an expression
    if value:match("^{{.*}}$") then
        -- Extract the expression content
        local expr = value:match("^{{(.*)}}$")
        if expr then
            -- For simple variable access like {{user.name}}, generate context access code
            -- Split on dots to handle nested access
            local parts = {}
            for part in expr:gmatch("[^.]+") do
                table.insert(parts, string.format("[%q]", part))
            end
            local access_code = "context" .. table.concat(parts)
            return string.format('tostring(%s or "")', access_code)
        end
    end
    -- For non-expression values, just return the literal string
    return escape_lua_string(value)
end

--- Compile a component template with provided attributes.
---@param component_template string The component's template string
---@param attributes table<string, table> Attribute values to inject into the component (each value is {type="string"|"code", value=string})
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

            -- Collect all expression tokens until EXPR_END
            local expr_tokens = {}
            while
                component_parser.pos <= #component_tokens
                and component_tokens[component_parser.pos].type ~= "EXPR_END"
            do
                table.insert(expr_tokens, component_tokens[component_parser.pos])
                component_parser.pos = component_parser.pos + 1
            end

            if
                component_parser.pos > #component_tokens
                or component_tokens[component_parser.pos].type ~= "EXPR_END"
            then
                error("Expected }} after expression in component")
            end
            component_parser.pos = component_parser.pos + 1

            -- Check if this expression contains filter pipelines
            local has_filters = false
            for _, token in ipairs(expr_tokens) do
                if token.type == "OPERATOR" and token.value == "|>" then
                    has_filters = true
                    break
                end
            end

            if has_filters then
                -- Handle filter pipeline expressions
                local filter_code = parse_filter_pipeline(expr_tokens, attributes)
                table.insert(
                    chunks,
                    string.format(
                        'tostring((function(c, fr) return %s end)(context, filter_registry) or "")',
                        filter_code
                    )
                )
            elseif #expr_tokens == 1 and expr_tokens[1].type == "IDENTIFIER" then
                local var_name = expr_tokens[1].value
                -- Check if this is an attribute, otherwise use normal context access
                if attributes[var_name] then
                    -- Attributes may be strings or Lua code marked with __CODE__
                    local attr_value = attributes[var_name]
                    if
                        type(attr_value) == "string"
                        and attr_value:sub(1, 8) == "__CODE__"
                    then
                        -- This is Lua code, insert it directly
                        table.insert(chunks, attr_value:sub(9))
                    else
                        -- String literal, escape it
                        table.insert(chunks, escape_lua_string(attr_value))
                    end
                else
                    -- Generate Lua code for safe table access and tostring conversion
                    table.insert(
                        chunks,
                        string.format('tostring(context[%q] or "")', var_name)
                    )
                end
            else
                -- Handle complex expressions by converting tokens back to Lua code
                local expr_parts = {}
                for _, token in ipairs(expr_tokens) do
                    if token.type == "IDENTIFIER" then
                        table.insert(expr_parts, "c." .. token.value)
                    elseif token.type == "LITERAL" then
                        if type(token.value) == "string" then
                            table.insert(expr_parts, string.format("%q", token.value))
                        else
                            table.insert(expr_parts, tostring(token.value))
                        end
                    elseif token.type == "OPERATOR" then
                        table.insert(expr_parts, token.value)
                    elseif token.type == "KEYWORD" then
                        table.insert(expr_parts, token.value)
                    else
                        table.insert(expr_parts, token.value or "")
                    end
                end
                local expr_str = table.concat(expr_parts, " ")

                -- Generate code to evaluate the expression safely
                table.insert(
                    chunks,
                    string.format(
                        'tostring((function(c) return %s end)(context) or "")',
                        expr_str
                    )
                )
            end
        elseif token.type == "COMPONENT_START" then
            -- Handle component usage within component template (composition)
            component_parser.pos = component_parser.pos + 1
            if
                component_parser.pos > #component_tokens
                or component_tokens[component_parser.pos].type ~= "COMPONENT_NAME"
            then
                error("Expected component name after < in component")
            end
            local sub_component_name = component_tokens[component_parser.pos].value
            component_parser.pos = component_parser.pos + 1

            -- Check if sub-component is registered
            local sub_component_template = component_registry[sub_component_name]
            if not sub_component_template then
                error("Component '" .. sub_component_name .. "' is not registered")
            end

            -- Parse attributes for sub-component
            local sub_attributes = {}
            if
                component_parser.pos <= #component_tokens
                and component_tokens[component_parser.pos].type == "COMPONENT_ATTRS"
            then
                local attr_table = component_tokens[component_parser.pos].value
                for attr_name, attr_info in pairs(attr_table) do
                    if attr_info.type == "string" then
                        sub_attributes[attr_name] = attr_info.value
                    elseif attr_info.type == "expression" then
                        -- For sub-component attributes, evaluate in the current component's context
                        local parts = {}
                        for part in attr_info.value:gmatch("[^.]+") do
                            table.insert(parts, string.format("[%q]", part))
                        end
                        sub_attributes[attr_name] = "__CODE__"
                            .. "tostring(context"
                            .. table.concat(parts)
                            .. ' or "")'
                    end
                end
                component_parser.pos = component_parser.pos + 1
            end

            -- Handle self-closing
            local is_self_closing = false
            if component_parser.pos <= #component_tokens then
                if
                    component_tokens[component_parser.pos].type
                    == "COMPONENT_SELF_CLOSE"
                then
                    is_self_closing = true
                elseif
                    component_tokens[component_parser.pos].type == "COMPONENT_OPEN"
                then
                    is_self_closing = false
                else
                    error("Expected component tag closure in component")
                end
                component_parser.pos = component_parser.pos + 1
            end

            if is_self_closing then
                -- Inline the sub-component
                local sub_component_chunks =
                    compile_component(sub_component_template, sub_attributes)
                for _, chunk in ipairs(sub_component_chunks) do
                    table.insert(chunks, chunk)
                end
            else
                error("Non-self-closing sub-components not yet supported")
            end
        elseif token.type == "STMT_START" then
            error("Statements not yet supported in components")
        else
            error(
                "Unexpected token in component: "
                    .. token.type
                    .. " at position "
                    .. component_parser.pos
            )
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
    local body_parts = {} -- Build the function body directly
    local conditional_stack = {} -- Stack to track nested conditionals

    -- Check for template inheritance
    local parent_template_name = nil
    local extends_found = false
    local content_before_extends = false

    -- Check if first non-whitespace content is {% extends %}
    local i = 1
    while i <= #tokens do
        local token = tokens[i]
        if token.type == "STMT_START" then
            i = i + 1
            if i <= #tokens and tokens[i].type == "EXTENDS" then
                -- Found extends statement
                if extends_found then
                    error("Multiple extends statements in template")
                end
                if content_before_extends then
                    error("extends must be first")
                end
                extends_found = true

                i = i + 1
                if i > #tokens or tokens[i].type ~= "LITERAL" or type(tokens[i].value) ~= "string" then
                    error("Expected quoted template name after extends")
                elseif tokens[i].value == "" then
                    error("extends requires a non-empty template name")
                end
                parent_template_name = tokens[i].value
                i = i + 1

                if i > #tokens or tokens[i].type ~= "STMT_END" then
                    error("Expected %} after extends statement")
                end
                i = i + 1
            elseif extends_found then
                -- After extends, only allow block statements
                if tokens[i].type == "BLOCK_START" then
                    -- Parse block name
                    i = i + 1
                    if i > #tokens or tokens[i].type ~= "IDENTIFIER" then
                        error("Expected block name after block")
                    end
                    local block_name = tokens[i].value
                    i = i + 1

                    if i > #tokens or tokens[i].type ~= "STMT_END" then
                        error("Expected %} after block name")
                    end
                    i = i + 1

                    -- Parse block content until endblock
                    local block_depth = 1
                    while i <= #tokens and block_depth > 0 do
                        if tokens[i].type == "STMT_START" then
                            i = i + 1
                            if i <= #tokens then
                                if tokens[i].type == "BLOCK_START" then
                                    block_depth = block_depth + 1
                                elseif tokens[i].type == "BLOCK_END" then
                                    block_depth = block_depth - 1
                                    if block_depth == 0 then
                                        i = i + 1
                                        if i <= #tokens and tokens[i].type == "STMT_END" then
                                            i = i + 1
                                        end
                                        break
                                    end
                                elseif tokens[i].type == "BLOCK_END" and block_depth == 1 then
                                    -- Found endblock for this block
                                    block_depth = block_depth - 1
                                    i = i + 1
                                    if i <= #tokens and tokens[i].type == "STMT_END" then
                                        i = i + 1
                                    end
                                    break
                                end
                            end
                        elseif tokens[i].type == "STMT_END" then
                            i = i + 1
                        else
                            i = i + 1
                        end
                    end

                    if block_depth > 0 then
                        error("Unclosed block '" .. block_name .. "'")
                    end
                elseif tokens[i].type == "BLOCK_END" then
                    error("endblock without matching block")
                else
                    error("Only block statements allowed in child templates")
                end
            else
                -- Statement before extends
                content_before_extends = true
                i = i + 1
            end
        elseif token.type == "TEXT" and not token.value:match("^%s*$") then
            -- Non-whitespace text content
            if extends_found then
                error("Only block statements and whitespace allowed in child templates")
            else
                content_before_extends = true
            end
            i = i + 1
        elseif token.type == "EXPR_START" or token.type == "COMPONENT_START" then
            -- Other content before extends
            if extends_found then
                error("Only block statements and whitespace allowed in child templates")
            else
                content_before_extends = true
            end
            i = i + 1
        else
            i = i + 1
        end
    end

    -- If this is an inheritance template, merge with parent
    if parent_template_name then
        if processing_templates[parent_template_name] then
            -- Circular dependency detected, handle gracefully
            processing_templates[parent_template_name] = nil
            -- Fall through to normal processing without inheritance
        end

        if not template_registry[parent_template_name] then
            error("Template '" .. parent_template_name .. "' not found")
        end

        processing_templates[parent_template_name] = true

        -- Extract child blocks as token arrays
        local child_blocks = {} -- block_name -> {tokens}
        local child_tokens = Tokenizer.tokenize(template_str)

        -- Skip to after extends
        local i = 1
        while i <= #child_tokens do
            if child_tokens[i].type == "STMT_START" then
                i = i + 1
                if i <= #child_tokens and child_tokens[i].type == "EXTENDS" then
                    -- Skip extends statement
                    while i <= #child_tokens and child_tokens[i].type ~= "STMT_END" do
                        i = i + 1
                    end
                    if i <= #child_tokens then i = i + 1 end
                    break
                end
            elseif child_tokens[i].type == "TEXT" and child_tokens[i].value:match("^%s*$") then
                i = i + 1
            else
                break
            end
        end

        -- Parse blocks
        while i <= #child_tokens do
            if child_tokens[i].type == "STMT_START" then
                i = i + 1
                if i <= #child_tokens and child_tokens[i].type == "BLOCK_START" then
                    i = i + 1
                    if i <= #child_tokens and child_tokens[i].type == "IDENTIFIER" then
                        local block_name = child_tokens[i].value
                        i = i + 1

                        if i <= #child_tokens and child_tokens[i].type == "STMT_END" then
                            i = i + 1

                            -- Collect block content tokens
                            local content_tokens = {}
                            local block_depth = 1
                            while i <= #child_tokens and block_depth > 0 do
                                if child_tokens[i].type == "STMT_START" then
                                    i = i + 1
                                    if i <= #child_tokens and child_tokens[i].type == "BLOCK_START" then
                                        block_depth = block_depth + 1
                                    elseif i <= #child_tokens and child_tokens[i].type == "BLOCK_END" then
                                        block_depth = block_depth - 1
                                        if block_depth == 0 then
                                            break
                                        end
                                    end
                                elseif child_tokens[i].type == "STMT_END" then
                                    i = i + 1
                                else
                                    table.insert(content_tokens, child_tokens[i])
                                    i = i + 1
                                end
                            end

                            child_blocks[block_name] = content_tokens
                        end
                    end
                end
            else
                i = i + 1
            end
        end

        -- Parse all blocks in the template
        local pos = 1
        while pos <= #template_str do
            -- Find next block start
            local block_start_pos = template_str:find("{% block ", pos)
            if not block_start_pos then break end

            -- Extract block name
            local name_start = block_start_pos + #"{% block "
            local name_end = template_str:find(" %}", name_start)
            if not name_end then break end

            local block_name = template_str:sub(name_start, name_end - 1)

            -- Find block content start and end
            local content_start = name_end + #" %}"
            local endblock_pos = template_str:find("{% endblock %}", content_start)
            if not endblock_pos then break end

            local content = template_str:sub(content_start, endblock_pos - 1)
            -- Trim whitespace but preserve internal formatting
            content = content:gsub("^%s*(.-)%s*$", "%1")

            child_blocks[block_name] = content
            pos = endblock_pos + #"{% endblock %}"
        end

        -- Tokenize parent template and replace blocks at token level
        local parent_tokens = Tokenizer.tokenize(template_registry[parent_template_name])
        tokens = {}

        local i = 1
        while i <= #parent_tokens do
            local token = parent_tokens[i]
            if token.type == "STMT_START" then
                -- Check if previous token was whitespace that should be consumed
                local prev_token_idx = i - 1
                local consumed_whitespace = false
                if prev_token_idx >= 1 and parent_tokens[prev_token_idx].type == "TEXT" and parent_tokens[prev_token_idx].value:match("^%s*$") then
                    -- Remove the whitespace token
                    table.remove(tokens, #tokens)
                    consumed_whitespace = true
                end

                i = i + 1
                if i <= #parent_tokens and parent_tokens[i].type == "BLOCK_START" then
                    i = i + 1
                    if i <= #parent_tokens and parent_tokens[i].type == "IDENTIFIER" then
                        local block_name = parent_tokens[i].value
                        i = i + 1

                        if i <= #parent_tokens and parent_tokens[i].type == "STMT_END" then
                            i = i + 1

                            -- Check if child overrides this block
                            if child_blocks[block_name] then
                                -- Check if parent block is empty (no content between block tags)
                                local parent_block_start = i
                                local is_empty_block = true
                                local temp_depth = 1
                                local temp_i = i
                                while temp_i <= #parent_tokens and temp_depth > 0 do
                                    local temp_token = parent_tokens[temp_i]
                                    if temp_token.type == "STMT_START" then
                                        temp_i = temp_i + 1
                                        if temp_i <= #parent_tokens and parent_tokens[temp_i].type == "BLOCK_START" then
                                            temp_depth = temp_depth + 1
                                        elseif temp_i <= #parent_tokens and parent_tokens[temp_i].type == "BLOCK_END" then
                                            temp_depth = temp_depth - 1
                                            if temp_depth == 0 then
                                                break
                                            end
                                        end
                                    elseif temp_token.type == "STMT_END" then
                                        temp_i = temp_i + 1
                                    else
                                        if temp_token.type ~= "TEXT" or not temp_token.value:match("^%s*$") then
                                            is_empty_block = false
                                        end
                                        temp_i = temp_i + 1
                                    end
                                end

                                -- Replace with child content tokens
                                local child_tokens = child_blocks[block_name]
                                if is_empty_block then
                                    -- For empty parent blocks, trim all leading/trailing whitespace from child
                                    local start_idx = 1
                                    while start_idx <= #child_tokens and child_tokens[start_idx].type == "TEXT" and child_tokens[start_idx].value:match("^%s*$") do
                                        start_idx = start_idx + 1
                                    end
                                    local end_idx = #child_tokens
                                    while end_idx >= start_idx and child_tokens[end_idx].type == "TEXT" and child_tokens[end_idx].value:match("^%s*$") do
                                        end_idx = end_idx - 1
                                    end
                                    for j = start_idx, end_idx do
                                        table.insert(tokens, child_tokens[j])
                                    end
                                else
                                    -- For non-empty parent blocks, preserve child formatting
                                    for _, child_token in ipairs(child_tokens) do
                                        table.insert(tokens, child_token)
                                    end
                                end
                                -- Skip parent content until endblock
                                local block_depth = 1
                                while i <= #parent_tokens and block_depth > 0 do
                                    local block_token = parent_tokens[i]
                                    if block_token.type == "STMT_START" then
                                        i = i + 1
                                        if i <= #parent_tokens and parent_tokens[i].type == "BLOCK_START" then
                                            block_depth = block_depth + 1
                                        elseif i <= #parent_tokens and parent_tokens[i].type == "BLOCK_END" then
                                            block_depth = block_depth - 1
                                            if block_depth == 0 then
                                                i = i + 1 -- Skip BLOCK_END
                                                if i <= #parent_tokens and parent_tokens[i].type == "STMT_END" then
                                                    i = i + 1 -- Skip STMT_END
                                                end
                                                break
                                            end
                                        end
                                    elseif block_token.type == "STMT_END" then
                                        i = i + 1
                                    else
                                        -- Skip parent content
                                        i = i + 1
                                    end
                                end
                            else
                                -- Keep parent content until endblock
                                local block_depth = 1
                                while i <= #parent_tokens and block_depth > 0 do
                                    local block_token = parent_tokens[i]
                                    if block_token.type == "STMT_START" then
                                        i = i + 1
                                        if i <= #parent_tokens and parent_tokens[i].type == "BLOCK_START" then
                                            block_depth = block_depth + 1
                                        elseif i <= #parent_tokens and parent_tokens[i].type == "BLOCK_END" then
                                            block_depth = block_depth - 1
                                            if block_depth == 0 then
                                                i = i + 1 -- Skip BLOCK_END
                                                if i <= #parent_tokens and parent_tokens[i].type == "STMT_END" then
                                                    i = i + 1 -- Skip STMT_END
                                                end
                                                break
                                            end
                                        end
                                    elseif block_token.type == "STMT_END" then
                                        i = i + 1
                                    else
                                        table.insert(tokens, block_token)
                                        i = i + 1
                                    end
                                end
                            end
                        end
                    end
                else
                    -- Not a block, add back STMT_START
                    table.insert(tokens, {type = "STMT_START"})
                end
            else
                table.insert(tokens, token)
                i = i + 1
            end
        end

        parser = { tokens = tokens, pos = 1 }

        processing_templates[parent_template_name] = nil
    end

    -- Start building the function body
    table.insert(body_parts, "local context, filter_registry = ...")
    table.insert(body_parts, "local parts = {}")
    table.insert(body_parts, "local function is_truthy(val)")
    table.insert(
        body_parts,
        "  return val ~= false and val ~= nil and val ~= 0 and val ~= '' and (type(val) ~= 'table' or next(val) ~= nil)"
    )
    table.insert(body_parts, "end")

    while parser.pos <= #tokens do
        local token = tokens[parser.pos]
        if token.type == "TEXT" then
            table.insert(
                body_parts,
                "table.insert(parts, " .. escape_lua_string(token.value) .. ")"
            )
            parser.pos = parser.pos + 1
        elseif token.type == "EXPR_START" then
            parser.pos = parser.pos + 1

            -- Collect all expression tokens until EXPR_END
            local expr_tokens = {}
            while parser.pos <= #tokens and tokens[parser.pos].type ~= "EXPR_END" do
                table.insert(expr_tokens, tokens[parser.pos])
                parser.pos = parser.pos + 1
            end

            if parser.pos > #tokens or tokens[parser.pos].type ~= "EXPR_END" then
                error("Expected }} after expression")
            end
            parser.pos = parser.pos + 1

            -- Check if this expression contains filter pipelines
            local has_filters = false
            for _, token in ipairs(expr_tokens) do
                if token.type == "OPERATOR" and token.value == "|>" then
                    has_filters = true
                    break
                end
            end

            if has_filters then
                -- Handle filter pipeline expressions
                local filter_code = parse_filter_pipeline(expr_tokens)
                table.insert(
                    body_parts,
                    string.format(
                        'table.insert(parts, tostring((function(c, fr) return %s end)(context, filter_registry) or ""))',
                        filter_code
                    )
                )
            elseif #expr_tokens == 1 and expr_tokens[1].type == "IDENTIFIER" then
                -- Handle simple expressions (backward compatibility)
                local var_name = expr_tokens[1].value
                table.insert(
                    body_parts,
                    string.format(
                        'table.insert(parts, tostring(context[%q] or ""))',
                        var_name
                    )
                )
            else
                -- Handle complex expressions
                local expr_parts = {}
                local prev_token = nil
                for _, token in ipairs(expr_tokens) do
                    -- Add space between tokens unless this token is a dot or follows a dot
                    if
                        #expr_parts > 0
                        and not (token.type == "PUNCTUATION" and token.value == ".")
                        and not (
                            prev_token
                            and prev_token.type == "PUNCTUATION"
                            and prev_token.value == "."
                        )
                    then
                        expr_parts[#expr_parts] = expr_parts[#expr_parts] .. " "
                    end

                    if token.type == "IDENTIFIER" then
                        -- Don't add "c." prefix if this identifier follows a dot (property access)
                        if
                            prev_token
                            and prev_token.type == "PUNCTUATION"
                            and prev_token.value == "."
                        then
                            table.insert(expr_parts, token.value)
                        else
                            table.insert(expr_parts, "c." .. token.value)
                        end
                    elseif token.type == "LITERAL" then
                        if type(token.value) == "string" then
                            table.insert(expr_parts, string.format("%q", token.value))
                        else
                            table.insert(expr_parts, tostring(token.value))
                        end
                    elseif token.type == "OPERATOR" then
                        table.insert(expr_parts, token.value)
                    elseif token.type == "KEYWORD" then
                        table.insert(expr_parts, token.value)
                    else
                        table.insert(expr_parts, token.value or "")
                    end
                    prev_token = token
                end
                local expr_str = table.concat(expr_parts)
                table.insert(
                    body_parts,
                    string.format(
                        'table.insert(parts, tostring((function(c) return %s end)(context) or ""))',
                        expr_str
                    )
                )
            end
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
                -- Generate code that will error during rendering
                table.insert(
                    body_parts,
                    string.format(
                        "error(\"Component '%s' is not registered\")",
                        component_name
                    )
                )
                -- Skip the rest of component processing
                parser.pos = parser.pos + 1
                if
                    parser.pos <= #tokens
                    and tokens[parser.pos].type == "COMPONENT_ATTRS"
                then
                    parser.pos = parser.pos + 1
                end
                if
                    parser.pos <= #tokens
                    and (
                        tokens[parser.pos].type == "COMPONENT_SELF_CLOSE"
                        or tokens[parser.pos].type == "COMPONENT_OPEN"
                    )
                then
                    parser.pos = parser.pos + 1
                end
            else
                -- Parse attributes if present
                local attributes = {}
                local has_malformed_attrs = false
                if
                    parser.pos <= #tokens
                    and tokens[parser.pos].type == "COMPONENT_ATTRS"
                then
                    local attr_token = tokens[parser.pos]
                    local attr_table = attr_token.value

                    -- Check for malformed attributes
                    if attr_token.malformed and next(attr_token.malformed) then
                        has_malformed_attrs = true
                    else
                        -- Process valid attributes
                        for attr_name, attr_info in pairs(attr_table) do
                            if attr_info.type == "string" then
                                -- String literals are passed as-is (will be escaped when used)
                                attributes[attr_name] = attr_info.value
                            elseif attr_info.type == "expression" then
                                -- Expressions are stored as Lua code with a special marker
                                local parts = {}
                                for part in attr_info.value:gmatch("[^.]+") do
                                    table.insert(parts, string.format("[%q]", part))
                                end
                                attributes[attr_name] = "__CODE__"
                                    .. "tostring(context"
                                    .. table.concat(parts)
                                    .. ' or "")'
                            end
                        end
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

                if has_malformed_attrs then
                    -- Generate error for malformed attributes
                    table.insert(body_parts, 'error("malformed attribute")')
                    -- Skip component closure tokens to prevent cascading errors
                    if
                        parser.pos <= #tokens
                        and tokens[parser.pos].type == "COMPONENT_CLOSE"
                    then
                        parser.pos = parser.pos + 1
                        if
                            parser.pos <= #tokens
                            and tokens[parser.pos].type == "COMPONENT_NAME"
                        then
                            parser.pos = parser.pos + 1
                        end
                    end
                elseif is_self_closing then
                    -- Inline the component template with attributes as context
                    -- Attributes are already evaluated during parsing
                    local component_chunks =
                        compile_component(component_template, attributes)
                    for _, chunk in ipairs(component_chunks) do
                        table.insert(body_parts, "table.insert(parts, " .. chunk .. ")")
                    end
                else
                    -- Components must be self-closing - generate runtime error
                    table.insert(body_parts, 'error("malformed component tag")')
                end
            end
        elseif token.type == "COMPONENT_CLOSE" then
            -- Handle orphaned component close tags (from malformed component parsing)
            table.insert(body_parts, 'error("mismatched component tags")')
            parser.pos = parser.pos + 1
            if
                parser.pos <= #tokens
                and tokens[parser.pos].type == "COMPONENT_NAME"
            then
                parser.pos = parser.pos + 1
            end
        elseif token.type == "STMT_START" then
            -- Handle statement tokens
            parser.pos = parser.pos + 1
            if parser.pos > #tokens then
                error("Unexpected end of tokens in statement")
            end

            local stmt_token = tokens[parser.pos]
            if stmt_token.type == "IF_START" then
                -- Parse the condition
                parser.pos = parser.pos + 1
                local condition_tokens = {}

                -- Collect tokens until STMT_END
                while parser.pos <= #tokens and tokens[parser.pos].type ~= "STMT_END" do
                    table.insert(condition_tokens, tokens[parser.pos])
                    parser.pos = parser.pos + 1
                end

                if parser.pos > #tokens or tokens[parser.pos].type ~= "STMT_END" then
                    error("Unclosed if statement")
                end

                -- Validate condition syntax
                if #condition_tokens > 0 then
                    local last_token = condition_tokens[#condition_tokens]
                    -- Check for incomplete operators (operators at end without right operand)
                    if
                        last_token.type == "OPERATOR"
                        or (
                            last_token.type == "PUNCTUATION"
                            and (
                                last_token.value == "=="
                                or last_token.value == "!="
                                or last_token.value == "<"
                                or last_token.value == "<="
                                or last_token.value == ">"
                                or last_token.value == ">="
                            )
                        )
                    then
                        error(
                            "Invalid syntax in if condition: incomplete expression '"
                                .. last_token.value
                                .. "' requires a right operand"
                        )
                    end
                    -- Check for incomplete boolean operators
                    if
                        last_token.type == "KEYWORD"
                        and (
                            last_token.value == "and"
                            or last_token.value == "or"
                            or last_token.value == "not"
                        )
                    then
                        error(
                            "Invalid syntax in if condition: '"
                                .. last_token.value
                                .. "' requires an operand"
                        )
                    end
                end

                -- Generate condition expression
                local condition_parts = {}
                local prev_token = nil
                for _, token in ipairs(condition_tokens) do
                    -- Add space between tokens unless this token is a dot or follows a dot
                    if
                        #condition_parts > 0
                        and not (token.type == "PUNCTUATION" and token.value == ".")
                        and not (
                            prev_token
                            and prev_token.type == "PUNCTUATION"
                            and prev_token.value == "."
                        )
                    then
                        condition_parts[#condition_parts] = condition_parts[#condition_parts]
                            .. " "
                    end

                    if token.type == "IDENTIFIER" then
                        -- Don't add "c." prefix if this identifier follows a dot (property access)
                        if
                            prev_token
                            and prev_token.type == "PUNCTUATION"
                            and prev_token.value == "."
                        then
                            table.insert(condition_parts, token.value)
                        else
                            table.insert(condition_parts, "c." .. token.value)
                        end
                    elseif token.type == "LITERAL" then
                        if type(token.value) == "string" then
                            table.insert(
                                condition_parts,
                                string.format("%q", token.value)
                            )
                        else
                            table.insert(condition_parts, tostring(token.value))
                        end
                    elseif token.type == "OPERATOR" then
                        table.insert(condition_parts, token.value)
                    elseif token.type == "PUNCTUATION" then
                        table.insert(condition_parts, token.value)
                    else
                        table.insert(condition_parts, token.value or "")
                    end
                    prev_token = token
                end

                local condition_expr = table.concat(condition_parts, " ")
                if condition_expr == "" then
                    error(
                        "Empty if condition: {% if %} requires a condition expression"
                    )
                end

                -- Start conditional block with template-language truthiness
                table.insert(
                    body_parts,
                    string.format(
                        "if is_truthy((function(c) return %s end)(context)) then",
                        condition_expr
                    )
                )
                table.insert(conditional_stack, true)
            elseif stmt_token.type == "IF_END" then
                -- End conditional block
                if #conditional_stack == 0 then
                    error("Unexpected endif without matching if")
                end
                table.remove(conditional_stack)
                table.insert(body_parts, "end")
                parser.pos = parser.pos + 1

                if parser.pos > #tokens or tokens[parser.pos].type ~= "STMT_END" then
                    error("Unclosed endif statement")
                end
            elseif stmt_token.type == "FOR_START" then
                -- Parse the for loop: {% for var in collection %} or {% for key, value in pairs(collection) %}
                parser.pos = parser.pos + 1

                -- Check if this is key-value iteration (has comma)
                local is_key_value = false
                local loop_var1, loop_var2

                -- Expect first variable name
                if parser.pos > #tokens or tokens[parser.pos].type ~= "IDENTIFIER" then
                    error("Expected variable name after 'for'")
                end
                loop_var1 = tokens[parser.pos].value
                parser.pos = parser.pos + 1

                -- Check for comma (indicates key-value iteration)
                if
                    parser.pos <= #tokens
                    and tokens[parser.pos].type == "PUNCTUATION"
                    and tokens[parser.pos].value == ","
                then
                    is_key_value = true
                    parser.pos = parser.pos + 1

                    -- Expect second variable name
                    if
                        parser.pos > #tokens
                        or tokens[parser.pos].type ~= "IDENTIFIER"
                    then
                        error(
                            "Expected second variable name after comma in key-value for loop"
                        )
                    end
                    loop_var2 = tokens[parser.pos].value
                    parser.pos = parser.pos + 1
                end

                -- Expect 'in' keyword
                if
                    parser.pos > #tokens
                    or tokens[parser.pos].type ~= "KEYWORD"
                    or tokens[parser.pos].value ~= "in"
                then
                    error("Expected 'in' keyword after loop variable(s)")
                end
                parser.pos = parser.pos + 1

                -- Collect collection expression tokens until STMT_END
                local collection_tokens = {}
                while parser.pos <= #tokens and tokens[parser.pos].type ~= "STMT_END" do
                    table.insert(collection_tokens, tokens[parser.pos])
                    parser.pos = parser.pos + 1
                end

                if parser.pos > #tokens or tokens[parser.pos].type ~= "STMT_END" then
                    error("Unclosed for statement")
                end

                -- For key-value iteration, extract the inner expression from pairs(...) or ipairs(...)
                local inner_collection_tokens = collection_tokens
                local use_pairs = false
                if is_key_value and #collection_tokens >= 3 then
                    if
                        collection_tokens[1].type == "KEYWORD"
                        and collection_tokens[1].value == "pairs"
                        and collection_tokens[2].type == "PUNCTUATION"
                        and collection_tokens[2].value == "("
                        and collection_tokens[#collection_tokens].type == "PUNCTUATION"
                        and collection_tokens[#collection_tokens].value == ")"
                    then
                        -- Extract tokens between pairs( and )
                        inner_collection_tokens = {}
                        for i = 3, #collection_tokens - 1 do
                            table.insert(inner_collection_tokens, collection_tokens[i])
                        end
                        use_pairs = true
                    elseif
                        collection_tokens[1].type == "KEYWORD"
                        and collection_tokens[1].value == "ipairs"
                        and collection_tokens[2].type == "PUNCTUATION"
                        and collection_tokens[2].value == "("
                        and collection_tokens[#collection_tokens].type == "PUNCTUATION"
                        and collection_tokens[#collection_tokens].value == ")"
                    then
                        -- Extract tokens between ipairs( and )
                        inner_collection_tokens = {}
                        for i = 3, #collection_tokens - 1 do
                            table.insert(inner_collection_tokens, collection_tokens[i])
                        end
                        use_pairs = false -- Use ipairs for indexed iteration
                    end
                end

                -- Generate collection expression
                local collection_parts = {}
                local prev_token = nil
                for _, token in ipairs(inner_collection_tokens) do
                    -- Add space between tokens unless this token is a dot or follows a dot
                    if
                        #collection_parts > 0
                        and not (token.type == "PUNCTUATION" and token.value == ".")
                        and not (
                            prev_token
                            and prev_token.type == "PUNCTUATION"
                            and prev_token.value == "."
                        )
                    then
                        collection_parts[#collection_parts] = collection_parts[#collection_parts]
                            .. " "
                    end

                    if token.type == "IDENTIFIER" then
                        -- Don't add "c." prefix if this identifier follows a dot (property access)
                        if
                            prev_token
                            and prev_token.type == "PUNCTUATION"
                            and prev_token.value == "."
                        then
                            table.insert(collection_parts, token.value)
                        else
                            table.insert(collection_parts, "c." .. token.value)
                        end
                    elseif token.type == "LITERAL" then
                        if type(token.value) == "string" then
                            table.insert(
                                collection_parts,
                                string.format("%q", token.value)
                            )
                        else
                            table.insert(collection_parts, tostring(token.value))
                        end
                    elseif token.type == "OPERATOR" then
                        table.insert(collection_parts, token.value)
                    elseif token.type == "PUNCTUATION" then
                        table.insert(collection_parts, token.value)
                    else
                        table.insert(collection_parts, token.value or "")
                    end
                    prev_token = token
                end

                local collection_expr = table.concat(collection_parts, " ")
                if collection_expr == "" then
                    error(
                        "Empty for collection: {% for var in %} requires a collection expression"
                    )
                end

                -- Generate for loop code
                if is_key_value then
                    if use_pairs then
                        -- Key-value iteration: for key, value in pairs(collection)
                        table.insert(
                            body_parts,
                            string.format(
                                "for %s, %s in pairs((function(c) return %s end)(context) or {}) do",
                                loop_var1,
                                loop_var2,
                                collection_expr
                            )
                        )
                    else
                        -- Indexed array iteration: for index, item in ipairs(collection)
                        table.insert(
                            body_parts,
                            string.format(
                                "for %s, %s in ipairs((function(c) return %s end)(context) or {}) do",
                                loop_var1,
                                loop_var2,
                                collection_expr
                            )
                        )
                    end
                    table.insert(
                        body_parts,
                        string.format(
                            "local loop_context = setmetatable({%s = %s, %s = %s}, {__index = context})",
                            loop_var1,
                            loop_var1,
                            loop_var2,
                            loop_var2
                        )
                    )
                else
                    -- Array iteration: for _, item in ipairs(collection)
                    table.insert(
                        body_parts,
                        string.format(
                            "for _, %s in ipairs((function(c) return %s end)(context) or {}) do",
                            loop_var1,
                            collection_expr
                        )
                    )
                    table.insert(
                        body_parts,
                        string.format(
                            "local loop_context = setmetatable({%s = %s}, {__index = context})",
                            loop_var1,
                            loop_var1
                        )
                    )
                end
                table.insert(body_parts, "context = loop_context")
                table.insert(conditional_stack, "for") -- Track for loops
            elseif stmt_token.type == "FOR_END" then
                -- End for loop block
                if
                    #conditional_stack == 0
                    or conditional_stack[#conditional_stack] ~= "for"
                then
                    error("Unexpected endfor without matching for")
                end
                table.remove(conditional_stack)
                table.insert(body_parts, "context = getmetatable(context).__index") -- Restore original context
                table.insert(body_parts, "end")
                parser.pos = parser.pos + 1

                if parser.pos > #tokens or tokens[parser.pos].type ~= "STMT_END" then
                    error("Unclosed endfor statement")
                end
            elseif stmt_token.type == "BLOCK_START" then
                -- Skip block statements (shouldn't be here in final tokens)
                while parser.pos <= #tokens and tokens[parser.pos].type ~= "STMT_END" do
                    parser.pos = parser.pos + 1
                end
            elseif stmt_token.type == "BLOCK_END" then
                -- Skip block end statements (shouldn't be here in final tokens)
                parser.pos = parser.pos + 1
            else
                error("Unknown statement type: " .. stmt_token.type)
            end

            -- Skip the STMT_END
            parser.pos = parser.pos + 1
        else
            error("Unexpected token: " .. token.type .. " at position " .. parser.pos)
        end
    end

    -- Check for unclosed conditionals and loops
    if #conditional_stack > 0 then
        local unclosed_type = conditional_stack[#conditional_stack]
        if unclosed_type == "for" then
            error("Unclosed for statement(s)")
        else
            error("Unclosed if statement(s)")
        end
    end

    -- Finish the function body
    table.insert(body_parts, "return table.concat(parts)")

    -- Build the complete function body
    local body = table.concat(body_parts, "\n")
    local chunk, load_err = load(body)
    if not chunk then
        error("Failed to compile template: " .. load_err)
    end

    -- Note: filter_registry is passed as parameter to compiled functions

    -- Format the body for pretty printing
    local formatted_body = table.concat(body_parts, "\n")

    -- Return a table with render function and the formatted code
    local result = {
        render = function(context)
            -- Wrap context in a table if not already
            local ctx = type(context) == "table" and context or {}
            return chunk(ctx, filter_registry)
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

-- Load built-in filters automatically
for name, filter_func in pairs(builtin_filters) do
    Template.register_filter(name, filter_func)
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
