local path = require("nibiru.path")
local Template = require("nibiru.template")

local TemplateLoader = {}

--- Load templates from a directory recursively.
---@param directory_path string Path to the directory containing template files
function TemplateLoader.from_directory(directory_path)
    local files, err = path.files_from(directory_path)
    if not files then
        error("Failed to read directory '" .. directory_path .. "': " .. err)
    end

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

        -- Register the template using the relative path as the name
        Template.register(relative_path, content)
    end
end

return TemplateLoader