local Config = {}

--- Return the default configuration structure
function Config.defaults()
    return {
        templates = {
            directory = "templates"
        }
    }
end

return Config