local function app(environ, start_response)
    start_response("200 OK", {{"Content-Type", "text/plain"}})
    return ipairs({"Integration test app"})
end

return { app = app }