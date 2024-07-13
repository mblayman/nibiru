local connector = {}

--- Handle data received on the network connection.
--- @param data string
--- @return string
function connector.handle_connection(data)
    return "HTTP/1.1 200 OK\r\n\r\n" .. data
end

return connector
