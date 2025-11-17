local path = require("nibiru.path")
local Template = require("nibiru.template")

local TemplateLoader = {}

--- Parse a template string to extract the extends statement.
---@param template_content string The raw template content
---@return string|nil The parent template name if extends is found, nil otherwise
local function parse_extends(template_content)
    -- Look for extends "template_name" within {% %} blocks
    local extends_pattern = 'extends "([^"]+)"'
    local parent_name = template_content:match(extends_pattern)
    return parent_name
end

-- Expose for testing
TemplateLoader._parse_extends = parse_extends

--- Load templates from a directory recursively with dependency analysis.
---@param directory_path string Path to the directory containing template files
function TemplateLoader.from_directory(directory_path)
    local files, err = path.files_from(directory_path)
    if not files then
        error("Failed to read directory '" .. directory_path .. "': " .. err)
    end

    -- First pass: read all template contents
    local templates = {}
    for _, relative_path in ipairs(files) do
        -- Read file content
        local full_path = directory_path .. "/" .. relative_path
        local file, open_err = io.open(full_path, "r")
        if not file then
            error("Failed to open template file '" .. full_path .. "': " .. open_err)
        end

        local content, read_err = file:read("*a")
        file:close()

        if not content then
            error("Failed to read template file '" .. full_path .. "': " .. read_err)
        end

        templates[relative_path] = content
    end

    -- Second pass: build dependency graph
    local dependencies = {}  -- template -> list of templates it depends on
    local dependents = {}    -- template -> list of templates that depend on it

    for template_name, content in pairs(templates) do
        dependencies[template_name] = {}
        local parent = parse_extends(content)
        if parent then
            dependencies[template_name] = {parent}
            if not dependents[parent] then
                dependents[parent] = {}
            end
            table.insert(dependents[parent], template_name)
        end
    end

    -- Third pass: topological sort using Kahn's algorithm
    local sorted_templates = {}
    local in_degree = {}  -- template -> number of dependencies

    -- Initialize in-degrees
    for template_name in pairs(templates) do
        in_degree[template_name] = #dependencies[template_name]
    end

    -- Find templates with no dependencies (in-degree 0)
    local queue = {}
    for template_name, degree in pairs(in_degree) do
        if degree == 0 then
            table.insert(queue, template_name)
        end
    end

    -- Process queue
    while #queue > 0 do
        local current = table.remove(queue, 1)
        table.insert(sorted_templates, current)

        -- Reduce in-degree of all templates that depend on current
        if dependents[current] then
            for _, dependent in ipairs(dependents[current]) do
                in_degree[dependent] = in_degree[dependent] - 1
                if in_degree[dependent] == 0 then
                    table.insert(queue, dependent)
                end
            end
        end
    end

    -- Check for cycles
    if #sorted_templates ~= #files then
        -- Find templates involved in cycles
        local cycle_templates = {}
        for template_name in pairs(templates) do
            local found = false
            for _, sorted in ipairs(sorted_templates) do
                if sorted == template_name then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(cycle_templates, template_name)
            end
        end
        error("Circular dependency detected in templates: " .. table.concat(cycle_templates, ", "))
    end

    -- Fourth pass: register templates in dependency order
    for _, template_name in ipairs(sorted_templates) do
        Template.register(template_name, templates[template_name])
    end
end

return TemplateLoader

