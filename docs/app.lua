local Application = require("nibiru.application")
local http = require("nibiru.http")
local Route = require("nibiru.route")

local function index()
    return http.ok("Nibiru Docs")
end

local function slow()
    -- Simulate I/O request with 200ms delay
    os.execute("sleep 0.2")
    return http.ok("OK")
end

local routes = {
    Route("/", index),
    Route("/slow", slow),
}

return Application(routes)
