local M = {}

function M.handle_connection(data)
    print(data)
    print("hello world")
    return "Hello from Lua required package!"
end

return M
