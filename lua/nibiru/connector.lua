local connector = {}

--- Handle data received on the network connection.
--- @param data string
--- @return string
function connector.handle_connection(data)
    return "response to: " .. data
end

return connector
