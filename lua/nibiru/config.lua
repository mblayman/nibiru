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

    return config
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