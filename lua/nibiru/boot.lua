--- Bootstrap the system by generating the WSGI callable used with connection
--- handling.
---
--- @param app_module string The requireable module name containing the app
--- @param app_name string The name of the app callable within the module
local function bootstrap(app_module, app_name)
    local module = require(app_module)
    return module[app_name]
end

return { bootstrap = bootstrap }
