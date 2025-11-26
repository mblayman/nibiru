local assert = require("luassert")
local Config = require("nibiru.config")

local tests = {}

-- Test loading config from a valid file
function tests.test_load_valid_config()
    -- Create a temporary config file with unique name
    local temp_file = "/tmp/test_config_valid_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
        .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write([[
return {
    templates = {
        directory = "custom-templates"
    }
}
]])
    file:close()

    -- Load the config
    local config = Config.load(temp_file)

    -- Verify the config was loaded correctly
    assert.is_table(config)
    assert.is_table(config.templates)
    assert.equal("custom-templates", config.templates.directory)

    -- Clean up
    os.remove(temp_file)
end

-- Test that loading config fails when file doesn't exist
function tests.test_load_fails_when_no_file()
    -- Try to load from a nonexistent file
    local success, err = pcall(Config.load, "/tmp/nonexistent_config.lua")

    -- Should fail with error
    assert.is_false(success)
    assert.match("Failed to load config file", err)
    assert.match("No such file or directory", err)
end

-- Test Config.defaults() function
function tests.test_defaults_function()
    local defaults = Config.defaults()

    assert.is_table(defaults)
    assert.is_table(defaults.templates)
    assert.equal("templates", defaults.templates.directory)
end

-- Test error handling for invalid Lua syntax
function tests.test_load_invalid_lua_syntax()
    -- Create a config file with invalid Lua
    local temp_file = "/tmp/test_config_invalid_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
        .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write("return { invalid syntax {{{")
    file:close()

    -- Loading should fail gracefully
    local success, err = pcall(function()
        return Config.load(temp_file)
    end)

    assert.is_false(success, "Loading invalid config should fail")
    assert.is_string(err)

    -- Clean up
    os.remove(temp_file)
end

-- Test error handling for config that doesn't return a table
function tests.test_load_non_table_return()
    -- Create a config file that returns a string instead of a table
    local temp_file = "/tmp/test_config_non_table_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
        .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write('return "not a table"')
    file:close()

    -- Loading should fail gracefully
    local success, err = pcall(function()
        return Config.load(temp_file)
    end)

    assert.is_false(success, "Loading non-table config should fail")
    assert.is_string(err)

    -- Clean up
    os.remove(temp_file)
end

-- Test config validation - templates.directory must be a string
function tests.test_config_validation_invalid_directory_type()
    -- Create a config file with invalid directory type
    local temp_file = "/tmp/test_config_invalid_dir_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
        .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write([[
return {
    templates = {
        directory = 123  -- Should be a string
    }
}
]])
    file:close()

    -- Loading should fail due to validation
    local success, err = pcall(function()
        return Config.load(temp_file)
    end)

    assert.is_false(success, "Config with invalid directory type should fail validation")
    assert.is_string(err)

    -- Clean up
    os.remove(temp_file)
end

-- Test config validation - templates.directory cannot be empty string
function tests.test_config_validation_empty_directory()
    -- Create a config file with empty directory
    local temp_file = "/tmp/test_config_empty_dir_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
        .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write([[
return {
    templates = {
        directory = ""  -- Empty string should fail
    }
}
]])
    file:close()

    -- Loading should fail due to validation
    local success, err = pcall(function()
        return Config.load(temp_file)
    end)

    assert.is_false(success, "Config with invalid directory type should fail validation")
    assert.is_string(err)

    -- Clean up
    os.remove(temp_file)
end

-- Test loading config with partial settings (should merge with defaults)
function tests.test_load_partial_config()
    -- Create a config file with only some settings
    local temp_file = "/tmp/test_config_partial_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000)) .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write([[
return {
    templates = {
        directory = "my-templates"
    }
    -- Other settings should use defaults
}
]])
    file:close()

    local config = Config.load(temp_file)

    -- Verify specified setting
    assert.equal("my-templates", config.templates.directory)

    -- TODO: Add assertion to verify other settings use defaults
    -- Currently no way to check this without exposing internal config merging

    -- Clean up
    os.remove(temp_file)
end

-- Test loading config with extra unknown settings (should fail)
function tests.test_load_config_with_extra_settings()
    -- Create a config file with extra unknown settings
    local temp_file = "/tmp/test_config_extra_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000)) .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write([[
return {
    templates = {
        directory = "custom-templates"
    },
    unknown_setting = "should cause failure",
    another_unknown = { nested = "value" }
}
]])
    file:close()

    -- Loading should fail due to unknown settings
    local success, err = pcall(function()
        return Config.load(temp_file)
    end)

    assert.is_false(success, "Config with unknown settings should fail")
    assert.is_string(err)

    -- Clean up
    os.remove(temp_file)
end

-- Test loading empty config should use defaults
function tests.test_load_empty_config_uses_defaults()
    -- Create an empty config file
    local temp_file = "/tmp/test_config_empty_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000)) .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write([[
return {}
]])
    file:close()

    -- Loading should succeed and use defaults
    local config = Config.load(temp_file)

    -- Verify defaults are used
    assert.is_table(config)
    assert.is_table(config.templates)
    assert.equal("templates", config.templates.directory)

    -- Clean up
    os.remove(temp_file)
end

-- Test loading config with empty templates table should use default directory
function tests.test_load_config_empty_templates_uses_default_directory()
    -- Create a config file with empty templates table
    local temp_file = "/tmp/test_config_empty_templates_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000)) .. ".lua"
    local file = io.open(temp_file, "w")
    assert(file, "Failed to create temp file")
    file:write([[
return {
    templates = {}
}
]])
    file:close()

    -- Loading should succeed and use default directory
    local config = Config.load(temp_file)

    -- Verify defaults are used for missing directory
    assert.is_table(config)
    assert.is_table(config.templates)
    assert.equal("templates", config.templates.directory)

    -- Clean up
    os.remove(temp_file)
end

return tests

