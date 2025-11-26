local Config = {}

--- Load configuration from a file
-- @param config_path string: Path to the config file (optional, defaults to "./config.lua")
-- @return table: The loaded configuration merged with defaults
function Config.load(config_path)
    config_path = config_path or "./config.lua"

    local chunk, err = loadfile(config_path)
    if not chunk then
        -- Config file is required - don't fall back to defaults
        error("Failed to load config file '" .. config_path .. "': " .. err)
    end

    local config = chunk()
    if type(config) ~= "table" then
        error("Config file '" .. config_path .. "' must return a table")
    end

    -- Merge config with defaults
    config = Config.merge_defaults(config)

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

--- Merge user config with defaults
-- @param user_config table: The user-provided configuration
-- @return table: Configuration merged with defaults
function Config.merge_defaults(user_config)
    local defaults = Config.defaults()
    local merged = {}

    -- Start with defaults
    for key, value in pairs(defaults) do
        merged[key] = value
    end

    -- Override with user config, doing shallow merge for nested tables
    for key, value in pairs(user_config) do
        if type(value) == "table" and type(merged[key]) == "table" then
            -- Shallow merge nested tables
            for nested_key, nested_value in pairs(value) do
                merged[key][nested_key] = nested_value
            end
        else
            merged[key] = value
        end
    end

    return merged
end

return Config