--- Bootstrap the system by generating the WSGI callable used with connection
--- handling.
--- @param app_module string
--- @param app_name string
local function bootstrap(app_module, app_name)
    print(app_module .. " " .. app_name)
    -- TODO: return the application callable
end

return { bootstrap = bootstrap }
