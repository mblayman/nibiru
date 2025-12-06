local yaml = {}

-- Simple YAML parser for frontmatter with basic nested object support
function yaml.parse(input)
    if type(input) ~= "string" then
        return nil, "expected string"
    end

    -- Check for required delimiters
    if not input:match("^---\n") then
        return nil, "parsing error"
    end

    if not input:match("---$") then
        return nil, "missing closing"
    end

    -- Simple parsing: split by lines, handle basic nesting
    local result = {}
    local lines = {}
    for line in input:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

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

                if indent == 0 then
                    -- Root level
                    if value == "" and i < #lines then
                        -- Check if next line is indented
                        local next_line = lines[i + 1]
                        if next_line and next_line:match("^%s+") then
                            result[key] = {}
                        else
                            result[key] = parse_value(value)
                        end
                    else
                        result[key] = parse_value(value)
                    end
                else
                    -- Nested - find parent
                    local parent = nil
                    for j = i-1, 1, -1 do
                        local prev_line = lines[j]
                        if prev_line:match("%S") then
                            local prev_indent = 0
                            local prev_rest = prev_line
                            while prev_rest:sub(1, 1) == " " do
                                prev_indent = prev_indent + 1
                                prev_rest = prev_rest:sub(2)
                            end
                            if prev_indent < indent then
                                local prev_key = prev_rest:match("^([^:]+):")
                                if prev_key then
                                    parent = prev_key:gsub("%s+$", "")
                                    break
                                end
                            end
                        end
                    end

                    if parent and result[parent] then
                        result[parent][key] = parse_value(value)
                    end
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