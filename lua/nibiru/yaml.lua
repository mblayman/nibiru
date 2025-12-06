local yaml = {}

-- Simple YAML parser for frontmatter
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

    -- Simple parsing: split by lines, parse key-value pairs
    local result = {}
    local lines = {}
    for line in input:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local in_frontmatter = false
    for _, line in ipairs(lines) do
        if line == "---" then
            if not in_frontmatter then
                in_frontmatter = true
            else
                break -- End of frontmatter
            end
        elseif in_frontmatter then
            -- Check for invalid syntax (lines that don't match key: value pattern)
            if line:match("%S") and not line:match("^%s*[^:]+:%s*") then
                return nil, "parsing error"
            end

            local key, value = line:match("^%s*([^:]+):%s*(.*)$")
            if key and value then
                key = key:gsub("^%s+", ""):gsub("%s+$", "")
                value = value:gsub("^%s+", ""):gsub("%s+$", "")

                -- Check for indentation (should be at root level for this simple parser)
                if line:match("^%s+") then
                    return nil, "parsing error"
                end

                -- Parse value
                if value == "true" then
                    result[key] = true
                elseif value == "false" then
                    result[key] = false
                elseif tonumber(value) then
                    result[key] = tonumber(value)
                elseif value:sub(1,1) == "[" and value:sub(-1) == "]" then
                    -- Simple array parsing
                    local array = {}
                    for item in value:sub(2, -2):gmatch("[^,]+") do
                        item = item:gsub("^%s+", ""):gsub("%s+$", "")
                        if item:sub(1,1) == '"' and item:sub(-1) == '"' then
                            item = item:sub(2, -2)
                        end
                        table.insert(array, item)
                    end
                    result[key] = array
                elseif value == "" then
                    -- Empty value - could be start of nested object, but for now treat as empty string
                    result[key] = ""
                else
                    -- Remove quotes if present
                    if value:sub(1,1) == '"' and value:sub(-1) == '"' then
                        value = value:sub(2, -2)
                    end
                    result[key] = value
                end
            end
        end
    end

    return result
end

return yaml