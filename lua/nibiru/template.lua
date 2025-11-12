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
            while component_parser.pos <= #component_tokens and component_tokens[component_parser.pos].type ~= "EXPR_END" do
                table.insert(expr_tokens, component_tokens[component_parser.pos])
                component_parser.pos = component_parser.pos + 1
            end

            if component_parser.pos > #component_tokens or component_tokens[component_parser.pos].type ~= "EXPR_END" then
                error("Expected }} after expression in component")
            end
            component_parser.pos = component_parser.pos + 1

            -- For now, handle simple expressions only
            if #expr_tokens == 1 and expr_tokens[1].type == "IDENTIFIER" then
                local var_name = expr_tokens[1].value
                -- Check if this is an attribute, otherwise use normal context access
                if attributes[var_name] then
                    -- Attributes may be strings or Lua code marked with __CODE__
                    local attr_value = attributes[var_name]
                    if type(attr_value) == "string" and attr_value:sub(1, 8) == "__CODE__" then
                        -- This is Lua code, insert it directly
                        table.insert(chunks, attr_value:sub(9))
                    else
                        -- String literal, escape it
                        table.insert(chunks, escape_lua_string(attr_value))
                    end
                else
                    -- Generate Lua code for safe table access and tostring conversion
                    table.insert(chunks, string.format('tostring(context[%q] or "")', var_name))
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
                table.insert(chunks, string.format('tostring((function(c) return %s end)(context) or "")', expr_str))
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
    local body_parts = {}  -- Build the function body directly
    local conditional_stack = {}  -- Stack to track nested conditionals

    -- Start building the function body
    table.insert(body_parts, "local context = ...")
    table.insert(body_parts, "local parts = {}")
    table.insert(body_parts, "local function is_truthy(val)")
    table.insert(body_parts, "  return val ~= false and val ~= nil and val ~= 0 and val ~= '' and (type(val) ~= 'table' or next(val) ~= nil)")
    table.insert(body_parts, "end")

    while parser.pos <= #tokens do
        local token = tokens[parser.pos]
        if token.type == "TEXT" then
            table.insert(body_parts, "table.insert(parts, " .. escape_lua_string(token.value) .. ")")
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

            -- Handle simple expressions (backward compatibility)
            if #expr_tokens == 1 and expr_tokens[1].type == "IDENTIFIER" then
                local var_name = expr_tokens[1].value
                table.insert(body_parts, string.format('table.insert(parts, tostring(context[%q] or ""))', var_name))
            else
                -- Handle complex expressions
                local expr_parts = {}
                local prev_token = nil
                for _, token in ipairs(expr_tokens) do
                    -- Add space between tokens unless this token is a dot or follows a dot
                    if #expr_parts > 0 and not (token.type == "PUNCTUATION" and token.value == ".") and not (prev_token and prev_token.type == "PUNCTUATION" and prev_token.value == ".") then
                        expr_parts[#expr_parts] = expr_parts[#expr_parts] .. " "
                    end

                    if token.type == "IDENTIFIER" then
                        -- Don't add "c." prefix if this identifier follows a dot (property access)
                        if prev_token and prev_token.type == "PUNCTUATION" and prev_token.value == "." then
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
                table.insert(body_parts, string.format('table.insert(parts, tostring((function(c) return %s end)(context) or ""))', expr_str))
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
                table.insert(body_parts, string.format('error("Component \'%s\' is not registered")', component_name))
                -- Skip the rest of component processing
                parser.pos = parser.pos + 1
                if parser.pos <= #tokens and tokens[parser.pos].type == "COMPONENT_ATTRS" then
                    parser.pos = parser.pos + 1
                end
                if parser.pos <= #tokens and (tokens[parser.pos].type == "COMPONENT_SELF_CLOSE" or tokens[parser.pos].type == "COMPONENT_OPEN") then
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
                if parser.pos <= #tokens and tokens[parser.pos].type == "COMPONENT_CLOSE" then
                    parser.pos = parser.pos + 1
                    if parser.pos <= #tokens and tokens[parser.pos].type == "COMPONENT_NAME" then
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
              if parser.pos <= #tokens and tokens[parser.pos].type == "COMPONENT_NAME" then
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
                        if last_token.type == "OPERATOR" or (last_token.type == "PUNCTUATION" and (last_token.value == "==" or last_token.value == "!=" or last_token.value == "<" or last_token.value == "<=" or last_token.value == ">" or last_token.value == ">=")) then
                            error("Invalid syntax in if condition: incomplete expression '" .. last_token.value .. "' requires a right operand")
                        end
                        -- Check for incomplete boolean operators
                        if last_token.type == "KEYWORD" and (last_token.value == "and" or last_token.value == "or" or last_token.value == "not") then
                            error("Invalid syntax in if condition: '" .. last_token.value .. "' requires an operand")
                        end
                    end

                     -- Generate condition expression
                    local condition_parts = {}
                    local prev_token = nil
                    for _, token in ipairs(condition_tokens) do
                        -- Add space between tokens unless this token is a dot or follows a dot
                        if #condition_parts > 0 and not (token.type == "PUNCTUATION" and token.value == ".") and not (prev_token and prev_token.type == "PUNCTUATION" and prev_token.value == ".") then
                            condition_parts[#condition_parts] = condition_parts[#condition_parts] .. " "
                        end

                        if token.type == "IDENTIFIER" then
                            -- Don't add "c." prefix if this identifier follows a dot (property access)
                            if prev_token and prev_token.type == "PUNCTUATION" and prev_token.value == "." then
                                table.insert(condition_parts, token.value)
                            else
                                table.insert(condition_parts, "c." .. token.value)
                            end
                        elseif token.type == "LITERAL" then
                            if type(token.value) == "string" then
                                table.insert(condition_parts, string.format("%q", token.value))
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
                        error("Empty if condition: {% if %} requires a condition expression")
                    end

                   -- Start conditional block with template-language truthiness
                   table.insert(body_parts, string.format("if is_truthy((function(c) return %s end)(context)) then", condition_expr))
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
                    -- Parse the for loop: {% for var in collection %}
                    parser.pos = parser.pos + 1

                    -- Expect variable name
                    if parser.pos > #tokens or tokens[parser.pos].type ~= "IDENTIFIER" then
                        error("Expected variable name after 'for'")
                    end
                    local loop_var = tokens[parser.pos].value
                    parser.pos = parser.pos + 1

                    -- Expect 'in' keyword
                    if parser.pos > #tokens or tokens[parser.pos].type ~= "KEYWORD" or tokens[parser.pos].value ~= "in" then
                        error("Expected 'in' keyword after loop variable")
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

                    -- Generate collection expression
                    local collection_parts = {}
                    local prev_token = nil
                    for _, token in ipairs(collection_tokens) do
                        -- Add space between tokens unless this token is a dot or follows a dot
                        if #collection_parts > 0 and not (token.type == "PUNCTUATION" and token.value == ".") and not (prev_token and prev_token.type == "PUNCTUATION" and prev_token.value == ".") then
                            collection_parts[#collection_parts] = collection_parts[#collection_parts] .. " "
                        end

                        if token.type == "IDENTIFIER" then
                            -- Don't add "c." prefix if this identifier follows a dot (property access)
                            if prev_token and prev_token.type == "PUNCTUATION" and prev_token.value == "." then
                                table.insert(collection_parts, token.value)
                            else
                                table.insert(collection_parts, "c." .. token.value)
                            end
                        elseif token.type == "LITERAL" then
                            if type(token.value) == "string" then
                                table.insert(collection_parts, string.format("%q", token.value))
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
                        error("Empty for collection: {% for var in %} requires a collection expression")
                    end

                    -- Generate for loop code
                    table.insert(body_parts, string.format("for _, %s in ipairs((function(c) return %s end)(context) or {}) do", loop_var, collection_expr))
                    table.insert(body_parts, string.format("local loop_context = setmetatable({%s = %s}, {__index = context})", loop_var, loop_var))
                    table.insert(body_parts, "context = loop_context")
                    table.insert(conditional_stack, "for")  -- Track for loops

                elseif stmt_token.type == "FOR_END" then
                    -- End for loop block
                    if #conditional_stack == 0 or conditional_stack[#conditional_stack] ~= "for" then
                        error("Unexpected endfor without matching for")
                    end
                    table.remove(conditional_stack)
                    table.insert(body_parts, "context = getmetatable(context).__index")  -- Restore original context
                    table.insert(body_parts, "end")
                    parser.pos = parser.pos + 1

                    if parser.pos > #tokens or tokens[parser.pos].type ~= "STMT_END" then
                        error("Unclosed endfor statement")
                    end
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

    -- Format the body for pretty printing
    local formatted_body = table.concat(body_parts, "\n")

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
