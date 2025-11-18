local Config = {}

--- Load configuration from a file
-- @param config_path string: Path to the config file (optional, defaults to "./config.lua")
-- @return table: The loaded configuration
function Config.load(config_path)
    config_path = config_path or "./config.lua"

    local chunk, err = loadfile(config_path)
    if not chunk then
        -- If config file doesn't exist, return defaults
        if err:match("No such file or directory") then
            return Config.defaults()
        end
        -- For other loadfile errors (syntax errors, etc.), still throw
        error("Failed to load config file '" .. config_path .. "': " .. err)
    end

    local config = chunk()
    if type(config) ~= "table" then
        error("Config file '" .. config_path .. "' must return a table")
    end

    -- Validate configuration structure
    Config.validate(config, config_path)

    return config
end

--- Validate configuration structure
-- @param config table: The configuration table to validate
-- @param config_path string: Path to the config file (for error messages)
function Config.validate(config, config_path)
    -- Check for unknown top-level keys
    local allowed_top_keys = { templates = true }
    for key, _ in pairs(config) do
        if not allowed_top_keys[key] then
            error("Config file '" .. config_path .. "' contains unknown setting '" .. key .. "'")
        end
    end

    -- Validate templates section
    if not config.templates or type(config.templates) ~= "table" then
        error("Config file '" .. config_path .. "' must have a 'templates' table")
    end

    -- Check for unknown keys in templates section
    local allowed_template_keys = { directory = true }
    for key, _ in pairs(config.templates) do
        if not allowed_template_keys[key] then
            error("Config file '" .. config_path .. "' contains unknown templates setting '" .. key .. "'")
        end
    end

    -- Validate templates.directory is a non-empty string
    if not config.templates.directory or type(config.templates.directory) ~= "string" or config.templates.directory == "" then
        error("Config file '" .. config_path .. "' templates.directory must be a non-empty string")
    end
end

--- Return the default configuration structure
function Config.defaults()
    return {
        templates = {
            directory = "templates"
        }
    }
end

return Config