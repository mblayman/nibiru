# Nibiru Configuration

Nibiru provides a flexible configuration system that allows you to customize framework behavior. Configuration is loaded explicitly and passed through the application initialization chain, giving you full control over when and how settings are applied.

## Configuration Overview

Nibiru's configuration system is designed to be:

- **Extensible**: New configuration options can be added without breaking changes
- **Testable**: Easy to inject different configurations for testing
- **Composable**: Configuration is passed through the application object graph

## Configuration Setup

Create a `config.lua` file alongside your application file. Start with an empty configuration and add settings as needed:

```lua
-- config.lua
return {
    -- Start empty - templates load from "templates" directory by default
}
```

To customize the template directory:

```lua
-- config.lua
return {
    templates = {
        directory = "my-templates"  -- Custom template directory
    }
}
```

### Application Integration

The Application automatically loads configuration during initialization:

```lua
-- ./app.lua
local Application = require("nibiru.application")

local app = Application(routes)
-- Configuration is automatically loaded from ./config.lua
```

## Configuration Reference

### Configuration Structure

```lua
return {
    templates = {
        directory = "templates"
    }
}
```

**Properties:**
- `templates.directory` (string): Path to the directory containing template files. Relative paths are resolved from the current working directory. Default: `"templates"`

### Runtime Configuration

Configuration is read-only after application initialization. For dynamic settings, use application state or external configuration services.

## Troubleshooting

### Common Issues

**"Template directory does not exist"**
- Check that the path in `config.templates.directory` exists
- Ensure paths are relative to the current working directory

**"Config file not found"**
- Verify `config.lua` exists alongside your application file
- Check file permissions

**"Invalid configuration format"**
- Ensure the config file returns a Lua table
- Check for syntax errors in the config file

### Configuration Validation

The config module validates settings and provides helpful error messages for common mistakes.
