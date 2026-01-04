--- @module nibiru.yaml
--- YAML parser for frontmatter with nested object support
--- Supports parsing YAML frontmatter strings with primitive types, arrays (inline and multi-line), nested objects, and folded block scalars (with chomp support)
--- Used primarily by the markdown parser for frontmatter extraction

--- @class yaml
--- YAML parser module for parsing YAML frontmatter strings with support for primitive types, arrays (inline and multi-line), nested objects, and folded block scalars (with chomp support)
local yaml = {}

--- Parse a YAML frontmatter string into a Lua table
--- @param input string The YAML string to parse (must start with --- and end with ---)
--- @return table|nil result The parsed YAML data as a Lua table, or nil on error
--- @return string|nil error Error message if parsing failed
--- @usage
--- local data, err = yaml.parse("---\ntitle: Hello\n---\n")
--- print(data.title) -- "Hello"
function yaml.parse(input)
    if type(input) ~= "string" then
        return nil, "expected string"
    end

    -- Check for required delimiters
    if not input:match("^---\n") then
        return nil, "YAML frontmatter must start with '---'"
    end

    if not input:match("---%s*$") then
        return nil, "missing closing"
    end

    -- Split into lines
    local lines = {}
    for line in input:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    -- Parse with proper nesting using context stack
    local result = {}
    local context_stack = {{table = result, indent = -1}} -- Root context

    local i = 2 -- Skip opening ---
    while i <= #lines and lines[i] ~= "---" do
        local line = lines[i]
        if line:match("%S") then
            -- Check for invalid syntax
            if not line:match("^%s*[^:]+:%s*") then
                local line_num = i - 1
                return nil, string.format("invalid YAML syntax at line %d: '%s'. Expected key-value pairs in format 'key: value'", line_num, line:gsub("^%s+", ""):gsub("%s+$", ""))
            end

            -- Parse line
            local indent = 0
            local rest = line
            while rest:sub(1, 1) == " " do
                indent = indent + 1
                rest = rest:sub(2)
            end

            local key, value = rest:match("^([^:]+):%s*(.*)$")
            if key then
                key = key:gsub("%s+$", "")
                value = value or ""

                -- Pop contexts that are at the same or deeper indentation
                while #context_stack > 1 and context_stack[#context_stack].indent >= indent do
                    table.remove(context_stack)
                end

                local current_context = context_stack[#context_stack]

                -- Check if this should create a nested object or array
                local should_nest = false
                local should_array = false
                if value == "" and i < #lines then
                    local next_line = lines[i + 1]
                    if next_line and next_line:match("%S") then
                        local next_indent = 0
                        local next_rest = next_line
                        while next_rest:sub(1, 1) == " " do
                            next_indent = next_indent + 1
                            next_rest = next_rest:sub(2)
                        end
                        if next_indent > indent then
                            -- Check if it starts with "- " (array item)
                            if next_rest:sub(1, 2) == "- " then
                                should_array = true
                            else
                                should_nest = true
                            end
                        end
                    end
                end

                if should_array then
                    -- Create array and parse array items
                    local array_items = {}

                    -- Skip the current line (key:) and start from next line
                    i = i + 1

                    -- Collect array items until we reach a line with <= key indentation
                    while i <= #lines and lines[i] ~= "---" do
                        local array_line = lines[i]
                        if array_line:match("%S") then
                            local line_indent = 0
                            local line_rest = array_line
                            while line_rest:sub(1, 1) == " " do
                                line_indent = line_indent + 1
                                line_rest = line_rest:sub(2)
                            end

                            -- Stop if we reach a line at the same or less indentation than the key
                            if line_indent <= indent then
                                i = i - 1  -- Back up so this line gets processed as a new key
                                break
                            end

                            -- Include lines that start with "- " (array items)
                            if line_rest:sub(1, 2) == "- " then
                                -- Extract the item value after "- "
                                local item_value = line_rest:sub(3)
                                -- Trim whitespace and handle quotes
                                item_value = item_value:gsub("^%s+", ""):gsub("%s+$", "")
                                if item_value:sub(1,1) == '"' and item_value:sub(-1) == '"' then
                                    item_value = item_value:sub(2, -2)
                                elseif item_value:sub(1,1) == "'" and item_value:sub(-1) == "'" then
                                    item_value = item_value:sub(2, -2)
                                end
                                table.insert(array_items, item_value)
                            end
                        end
                        i = i + 1
                    end

                    current_context.table[key] = array_items
                elseif should_nest then
                    -- Create nested table and push new context
                    current_context.table[key] = {}
                    table.insert(context_stack, {table = current_context.table[key], indent = indent})
                elseif value:sub(1,1) == ">" then
                    -- Handle folded block scalar
                    local block_lines = {}
                    local block_indent = indent + 2  -- Block content starts 2 spaces after key
                    local chomp = value:sub(1,2) == ">-"  -- Check for chomp indicator

                    -- Skip the current line (key: > or >-) and start from next line
                    i = i + 1

                    -- Collect block lines until we reach a line with <= key indentation
                    while i <= #lines and lines[i] ~= "---" do
                        local block_line = lines[i]
                        if block_line:match("%S") then
                            local line_indent = 0
                            local line_rest = block_line
                            while line_rest:sub(1, 1) == " " do
                                line_indent = line_indent + 1
                                line_rest = line_rest:sub(2)
                            end

                            -- Stop if we reach a line at the same or less indentation than the key
                            if line_indent <= indent then
                                i = i - 1  -- Back up so this line gets processed as a new key
                                break
                            end

                            -- Only include lines that are part of the block (indented beyond block start)
                            if line_indent >= block_indent then
                                -- Remove the block indentation
                                local content = block_line:sub(block_indent + 1)
                                table.insert(block_lines, content)
                            end
                        else
                            -- Empty line - still part of block
                            table.insert(block_lines, "")
                        end
                        i = i + 1
                    end

                    -- Join folded block: lines with spaces
                    local folded_value = table.concat(block_lines, " ")
                    -- Add trailing newline unless chomp is specified
                    if not chomp then
                        folded_value = folded_value .. "\n"
                    end
                    current_context.table[key] = folded_value
                else
                    -- Set value in current context
                    current_context.table[key] = parse_value(value)
                end
            end
        end
        i = i + 1
    end

    return result
end

--- Parse a YAML value string into the appropriate Lua type
--- @param value string The value string to parse
--- @return any The parsed value (boolean, number, string, or array)
function parse_value(value)
    value = value:gsub("^%s+", ""):gsub("%s+$", "")

    if value == "true" then
        return true
    elseif value == "false" then
        return false
    elseif tonumber(value) then
        return tonumber(value)
    elseif value:sub(1,1) == "[" and value:sub(-1) == "]" then
        local array = {}
        for item in value:sub(2, -2):gmatch("[^,]+") do
            item = item:gsub("^%s+", ""):gsub("%s+$", "")
            if item:sub(1,1) == '"' and item:sub(-1) == '"' then
                item = item:sub(2, -2)
            elseif item:sub(1,1) == "'" and item:sub(-1) == "'" then
                item = item:sub(2, -2)
            end
            table.insert(array, item)
        end
        return array
    else
        if value:sub(1,1) == '"' and value:sub(-1) == '"' then
            value = value:sub(2, -2)
        elseif value:sub(1,1) == "'" and value:sub(-1) == "'" then
            value = value:sub(2, -2)
        end
        return value
    end
end

return yaml