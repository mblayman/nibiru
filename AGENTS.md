# AGENTS.md

## Build/Lint/Test Commands
- **Build**: `make build` (compiles C code and Lua)
- **Run**: `make run` (builds and starts server)
- **Test all**: `luatest tests/`
- **Test single**: `luatest tests/test_filename.lua` (e.g., `luatest tests/test_template.lua`)
- **Format**: `stylua lua/` (Lua formatting per .stylua.toml: 4 spaces, 88 columns, Unix endings)
- **Lint**: Use Lua LSP with .luarc.json for static analysis

## Code Style Guidelines
- **Language**: Lua (dynamic typing, no explicit types)
- **Imports**: Use `require("module.path")` for modules
- **Naming**: snake_case for functions/variables (e.g., `escape_lua_string`), PascalCase for modules
- **Functions**: Define as `local function name(...)` or `function Module:name(...)`
- **Error Handling**: Use `error("message")` for exceptions; avoid pcall unless necessary
- **Formatting**: 4 spaces indentation, no tabs; max 88 columns; Unix line endings
- **Comments**: `--` for single-line; avoid unnecessary comments
- **Structure**: Keep functions short; use locals; follow existing patterns in codebase
- **Security**: Never log secrets; validate inputs; use safe table access (e.g., `context[key] or ""`)

No Cursor or Copilot rules found.</content>
<parameter name="filePath">/home/matt/Work/nibiru/AGENTS.md

BEFORE ANYTHING ELSE: run 'bd onboard' and follow the instructions
