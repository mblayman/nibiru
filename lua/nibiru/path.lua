local M = {}

-- Try to load the C library
local ok, core = pcall(require, "nibiru_core")
if ok then
    -- Use C library function
    M.files_from = core.files_from
else
    -- Fallback (limited functionality)
    M.files_from = function(path)
        error("Directory scanning requires nibiru_core C library")
    end
end

return M