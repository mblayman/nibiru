# Nibiru Path Utilities

Nibiru provides utility functions for working with file paths and directory operations. These functions are designed to be safe, efficient, and easy to use in web applications.

## File Discovery

### files_from

Recursively collect all files from a directory and return them as a sorted array of relative paths.

#### Syntax

```lua
local path = require("nibiru.path")
local files, err = path.files_from(directory_path)
```

#### Parameters

- `directory_path` (string): The directory path to scan for files. Can be an absolute or relative path.

#### Returns

- `files` (table|nil): Array of relative file paths sorted alphabetically, or `nil` if the path doesn't exist or isn't a directory
- `err` (string|nil): Error message if the operation failed

#### Examples

##### Basic Usage

```lua
local path = require("nibiru.path")

-- Get all files from a templates directory
local files = path.files_from("templates")
if files then
    for _, file in ipairs(files) do
        print("Found file: " .. file)
    end
end
```

##### Error Handling

```lua
local files, err = path.files_from("/nonexistent/directory")
if not files then
    print("Error: " .. err)  -- "Path does not exist or is not a directory"
end
```

##### Processing Template Files

```lua
local path = require("nibiru.path")
local Template = require("nibiru.template")

-- Load all template files from a directory
local template_files = path.files_from("templates")
if template_files then
    for _, filename in ipairs(template_files) do
        if filename:match("%.html$") then
            -- Load and register the template
            local file = io.open("templates/" .. filename, "r")
            if file then
                local content = file:read("*all")
                file:close()
                Template.register(filename, content)
            end
        end
    end
end
```

##### Building File Lists for Static Assets

```lua
local path = require("nibiru.path")

-- Get all CSS and JS files for asset processing
local assets = path.files_from("public/assets")
if assets then
    local css_files = {}
    local js_files = {}

    for _, file in ipairs(assets) do
        if file:match("%.css$") then
            table.insert(css_files, file)
        elseif file:match("%.js$") then
            table.insert(js_files, file)
        end
    end

    -- Use the file lists for bundling, caching, etc.
    print("Found " .. #css_files .. " CSS files and " .. #js_files .. " JS files")
end
```

#### Behavior

- **Recursive**: Scans all subdirectories recursively
- **Relative Paths**: Returns paths relative to the input directory
- **Sorted**: Results are sorted alphabetically
- **Hidden Files**: Includes files starting with `.` (dot files)
- **Directories**: Only returns files, not directories themselves
- **Empty Directories**: Returns an empty array for directories with no files

#### File Structure Example

Given this directory structure:
```
templates/
├── base.html
├── pages/
│   ├── about.html
│   └── home.html
└── partials/
    └── header.html
```

The function returns:
```lua
{
    "base.html",
    "pages/about.html",
    "pages/home.html",
    "partials/header.html"
}
```

#### Error Conditions

- **Non-existent path**: Returns `nil, "Path does not exist or is not a directory"`
- **File instead of directory**: Returns `nil, "Path does not exist or is not a directory"`
- **Permission denied**: Returns `nil, "Path does not exist or is not a directory"` (handled by underlying filesystem checks)

#### Performance Notes

- **Efficient**: Uses native C filesystem operations for optimal performance
- **Memory conscious**: Streams file discovery without loading file contents
- **Sorted results**: Built-in alphabetical sorting eliminates the need for post-processing
- **No duplicates**: Each file appears exactly once in the results

#### Use Cases

- **Template loading**: Automatically discover and register template files
- **Asset management**: Build lists of CSS, JS, or other static files
- **Content indexing**: Create file indexes for search or caching systems
- **Build systems**: Generate file lists for compilation or bundling processes
- **Backup utilities**: Collect files for archiving or synchronization

This function is particularly useful for applications that need to dynamically discover and process files, such as template engines, asset bundlers, or content management systems.
