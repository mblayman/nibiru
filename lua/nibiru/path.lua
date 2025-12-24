local M = {}

-- Load the C library (required)
local core = require("nibiru_core")

--- Recursively collect all files from a directory and return them as a sorted array of relative paths.
---
--- @param path string The directory path to scan for files
--- @return string[]|nil files Array of relative file paths sorted alphabetically, or nil if path doesn't exist or isn't a directory
--- @return string|nil error Error message if path is invalid
M.files_from = core.files_from

return M