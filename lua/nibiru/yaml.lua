local yaml = {}

-- YAML parser for frontmatter with proper nested object support
function yaml.parse(input)
    if type(input) ~= "string" then
        return nil, "expected string"
    end

    -- Check for required delimiters
    if not input:match("^---\n") then
        return nil, "parsing error"
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
                return nil, "parsing error"
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

                -- Check if this should create a nested object
                local should_nest = false
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
                            should_nest = true
                        end
                    end
                end

                if should_nest then
                    -- Create nested table and push new context
                    current_context.table[key] = {}
                    table.insert(context_stack, {table = current_context.table[key], indent = indent})
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
            end
            table.insert(array, item)
        end
        return array
    else
        if value:sub(1,1) == '"' and value:sub(-1) == '"' then
            value = value:sub(2, -2)
        end
        return value
    end
end

return yaml