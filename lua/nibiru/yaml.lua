local yaml = {}

-- YAML parser for frontmatter with nested object support
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

    -- Split into lines
    local lines = {}
    for line in input:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    -- Parse the frontmatter
    local result, err = parse_frontmatter(lines)
    if not result then
        return nil, err
    end

    return result
end

function parse_frontmatter(lines)
    local result = {}
    local i = 1

    -- Skip opening ---
    if lines[i] == "---" then
        i = i + 1
    end

    -- Parse until closing ---
    while i <= #lines and lines[i] ~= "---" do
        local line = lines[i]


        -- Skip empty lines
        if line:match("%S") then
            -- Check for invalid syntax
            if not line:match("^%s*[^:]+:%s*") then
                return nil, "parsing error"
            end

            -- Parse the line and determine nesting
            local success, indent, key, value = parse_line(line)
            if not success then
                return nil, "parsing error"
            end

            if indent == 0 then
                -- Root level key
                local parsed_value = parse_value(value)
                -- If value is empty and this might be a parent of nested keys, prepare for nesting
                if value == "" then
                    -- Check if next non-empty line is indented
                    local next_line = nil
                    for k = i+1, #lines do
                        if lines[k]:match("%S") and lines[k] ~= "---" then
                            next_line = lines[k]
                            break
                        end
                    end
                    if next_line then
                        local next_indent = 0
                        while next_line:sub(1, 1) == " " do
                            next_indent = next_indent + 1
                            next_line = next_line:sub(2)
                        end
                        if next_indent > 0 then
                            parsed_value = {}
                        end
                    end
                end
                result[key] = parsed_value
            else
                -- Nested key - validate indentation and find the parent
                local parent_key = nil
                local expected_indent = nil
                for j = i-1, 1, -1 do
                    local success2, prev_indent, prev_key = parse_line(lines[j])
                    if success2 then
                        if prev_indent < indent then
                            -- This is a potential parent
                            parent_key = prev_key
                            break
                        elseif prev_indent == indent then
                            -- Sibling at same level - check indentation consistency
                            if expected_indent and expected_indent ~= indent then
                                return nil, "parsing error"
                            end
                            expected_indent = indent
                        end
                    end
                end

                -- Validate indentation is consistent (multiple of 2)
                if indent % 2 ~= 0 then
                    return nil, "parsing error"
                end

                if parent_key then
                    if not result[parent_key] then
                        result[parent_key] = {}
                    elseif type(result[parent_key]) ~= "table" then
                        return nil, "parsing error"
                    end

                    local parsed_value = parse_value(value)
                    result[parent_key][key] = parsed_value
                else
                    return nil, "parsing error"
                end
            end
                -- For nested objects, we need to handle this differently
                -- For now, let's handle the simple case where we have author: followed by indented keys
                break
            end

            if indent == 0 then
                -- Root level key
                local parsed_value = parse_value(value)
                -- If value is empty and this might be a parent of nested keys, prepare for nesting
                if value == "" then
                    -- Check if next non-empty line is indented
                    local next_line = nil
                    for k = i+1, #lines do
                        if lines[k]:match("%S") and lines[k] ~= "---" then
                            next_line = lines[k]
                            break
                        end
                    end
                    if next_line then
                        local next_indent = 0
                        while next_line:sub(1, 1) == " " do
                            next_indent = next_indent + 1
                            next_line = next_line:sub(2)
                        end
                        if next_indent > 0 then
                            parsed_value = {}
                        end
                    end
                end
                result[key] = parsed_value
            else
                -- Nested key - find the parent
                local parent_key = nil
                local parent_indent = 0
                for j = i-1, 1, -1 do
                    local success2, prev_indent, prev_key = parse_line(lines[j])
                    if success2 and prev_indent < indent then
                        parent_key = prev_key
                        parent_indent = prev_indent
                        break
                    end
                end



                if parent_key then
                    if not result[parent_key] then
                        result[parent_key] = {}
                    elseif type(result[parent_key]) ~= "table" then
                        return nil, "parsing error"
                    end

                    local parsed_value = parse_value(value)
                    result[parent_key][key] = parsed_value
                else
                    return nil, "parsing error"
                end
            end
        end

        i = i + 1
    end

    return result
end

function parse_line(line)
    local indent = 0
    local rest = line

    -- Count leading spaces
    while rest:sub(1, 1) == " " do
        indent = indent + 1
        rest = rest:sub(2)
    end

    -- Parse key: value
    local key, value = rest:match("^([^:]+):%s*(.*)$")
    if key then
        key = key:gsub("%s+$", "")
        value = value or ""
        return true, indent, key, value
    end

    return false, 0, nil, nil
end

function parse_value(value)
    value = value:gsub("^%s+", ""):gsub("%s+$", "")

    -- Parse as boolean
    if value == "true" then
        return true
    elseif value == "false" then
        return false
    end

    -- Parse as number
    local num = tonumber(value)
    if num then
        return num
    end

    -- Parse as array
    if value:sub(1,1) == "[" and value:sub(-1) == "]" then
        local array = {}
        for item in value:sub(2, -2):gmatch("[^,]+") do
            item = item:gsub("^%s+", ""):gsub("%s+$", "")
            if item:sub(1,1) == '"' and item:sub(-1) == '"' then
                item = item:sub(2, -2)
            end
            table.insert(array, item)
        end
        return array
    end

    -- Parse as string
    if value:sub(1,1) == '"' and value:sub(-1) == '"' then
        value = value:sub(2, -2)
    end

    return value
end

return yaml