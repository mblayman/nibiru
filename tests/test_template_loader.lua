local TemplateLoader = require("nibiru.loader")
local Template = require("nibiru.template")

local tests = {}

-- Test basic directory loading with multiple template files.
function tests.test_from_directory_basic()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_loader_basic_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create test template files
    local file1 = io.open(temp_dir .. "/index.html", "w")
    file1:write("<h1>{{title}}</h1>")
    file1:close()

    local file2 = io.open(temp_dir .. "/partial.html", "w")
    file2:write("<div>{{content}}</div>")
    file2:close()

    -- Load templates from directory
    TemplateLoader.from_directory(temp_dir)

    -- Verify templates were registered by trying to extend them
    -- If templates weren't registered, this would fail with "Template 'index.html' not found"
    local success1, result1 = pcall(function()
        local index_extending = Template('{% extends "index.html" %}')
        return index_extending({ title = "Hello" })
    end)
    assert(success1, "Template 'index.html' should be registered")
    assert(result1 == "<h1>Hello</h1>", "Template should render correctly")

    local success2, result2 = pcall(function()
        local partial_extending = Template('{% extends "partial.html" %}')
        return partial_extending({ content = "Loaded Content" })
    end)
    assert(success2, "Template 'partial.html' should be registered")
    assert(result2 == "<div>Loaded Content</div>", "Template should render correctly")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test error handling for nonexistent directory.
function tests.test_from_directory_nonexistent()
    -- Test with nonexistent directory
    local success, err = pcall(function()
        TemplateLoader.from_directory("/tmp/nonexistent_templates_dir_12345")
    end)

    assert(not success, "Should fail with nonexistent directory")
    assert(
        err:match("Failed to read directory"),
        "Should give appropriate error message"
    )
end

-- Test nested directory structure with proper relative paths.
function tests.test_from_directory_nested()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_loader_nested_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir .. "/pages")
    os.execute("mkdir -p " .. temp_dir .. "/partials")

    -- Create test template files in nested structure
    local base_file = io.open(temp_dir .. "/base.html", "w")
    base_file:write("<html>{{body}}</html>")
    base_file:close()

    local index_file = io.open(temp_dir .. "/pages/index.html", "w")
    index_file:write("<h1>Home</h1>")
    index_file:close()

    local footer_file = io.open(temp_dir .. "/partials/footer.html", "w")
    footer_file:write("<p>Footer</p>")
    footer_file:close()

    -- Load all templates with proper relative paths
    TemplateLoader.from_directory(temp_dir)

    -- Verify all templates were registered with correct relative paths
    local success1, result1 = pcall(function()
        local base_extending = Template('{% extends "base.html" %}')
        return base_extending({ body = "Test Body" })
    end)
    assert(success1, "Template 'base.html' should be registered")
    assert(result1 == "<html>Test Body</html>", "Template should render correctly")

    local success2, result2 = pcall(function()
        local index_extending = Template('{% extends "pages/index.html" %}')
        return index_extending({})
    end)
    assert(success2, "Template 'pages/index.html' should be registered")
    assert(result2 == "<h1>Home</h1>", "Template should render correctly")

    local success3, result3 = pcall(function()
        local footer_extending = Template('{% extends "partials/footer.html" %}')
        return footer_extending({})
    end)
    assert(success3, "Template 'partials/footer.html' should be registered")
    assert(result3 == "<p>Footer</p>", "Template should render correctly")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test loading from empty directory.
function tests.test_from_directory_empty()
    Template.clear_templates()

    -- Create a temporary empty directory
    local temp_dir = "/tmp/nibiru_test_loader_empty_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- This should succeed but load no templates
    TemplateLoader.from_directory(temp_dir)

    -- Verify no templates were registered by trying to extend a non-existent template
    local success, err = pcall(function()
        local template = Template('{% extends "nonexistent.html" %}')
        return template({})
    end)
    assert(not success, "Empty directory should not register any templates")
    assert(err:match("Template 'nonexistent.html' not found"), "Should confirm template doesn't exist")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test error handling for unreadable files.
function tests.test_from_directory_file_error()
    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_loader_error_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create readable file
    local readable_file = io.open(temp_dir .. "/readable.html", "w")
    readable_file:write("<h1>Test</h1>")
    readable_file:close()

    -- Create unreadable file
    local unreadable_file = io.open(temp_dir .. "/unreadable.html", "w")
    unreadable_file:write("<h1>Secret</h1>")
    unreadable_file:close()
    os.execute("chmod 000 " .. temp_dir .. "/unreadable.html")

    -- This should fail when trying to read the unreadable file
    local success, err = pcall(function()
        TemplateLoader.from_directory(temp_dir)
    end)

    -- Clean up
    os.execute("chmod 644 " .. temp_dir .. "/unreadable.html")
    os.execute("rm -rf " .. temp_dir)

    assert(not success, "Should fail with unreadable file")
    assert(err:match("Failed to read template file"), "Should give appropriate error message")
end

return tests

