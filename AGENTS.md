# AGENTS.md

## Build/Lint/Test Commands

- **Build**: `make build` (compiles C code and Lua)
- **Run**: `make run` (builds and starts server)
- **Clean**: `make clean` (removes build artifacts)
- **Deps**: `make deps` (installs luatest testing framework)
- **Test all**: `luatest tests/`
- **Test single**: `luatest tests/test_filename.lua` (e.g., `luatest tests/test_template.lua`)
- **Format Lua**: `stylua lua/` (4 spaces, 88 columns, Unix endings per .stylua.toml)
- **Format C**: `make format` (clang-format with LLVM style, 4-space indentation)
- **Lint**: Use Lua LSP with .luarc.json for static analysis

## Code Style Guidelines

- **Languages**: Lua (dynamic typing, no explicit types) and C (static typing)
- **Lua Imports**: Use `require("module.path")` for modules
- **Lua Naming**: snake_case for functions/variables, PascalCase for modules/classes
- **Lua Functions**: Define as `local function name(...)` or `function Module:name(...)`
- **Lua Error Handling**: Use `error("message")` for exceptions; avoid pcall unless necessary
- **Lua Formatting**: 4 spaces indentation, no tabs; max 88 columns; Unix line endings
- **Lua Comments**: `--` for single-line; use EmmyLua annotations for documentation
- **Lua Structure**: Keep functions short; use locals; follow existing patterns in codebase
- **C Naming**: snake_case for functions/variables/structs (e.g., `nibiru_load_registered_lua_function`)
- **C Formatting**: LLVM style with 4-space indentation; Doxygen-style comments (`/** */`)
- **C Structure**: Use structs for complex data; function pointers for callbacks
- **Security**: Never log secrets; validate inputs; use safe table access (e.g., `context[key] or ""`)

## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**
```bash
bd ready --json
```

**Create new issues:**
```bash
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**
```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**
```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`
6. **Commit together**: Always commit the `.beads/issues.jsonl` file together with the code changes so issue state stays in sync with code state

### Auto-Sync

bd automatically syncs with git:
- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### MCP Server (Recommended)

If using Claude or MCP-compatible clients, install the beads MCP server:

```bash
pip install beads-mcp
```

Add to MCP config (e.g., `~/.config/claude/config.json`):
```json
{
  "beads": {
    "command": "beads-mcp",
    "args": []
  }
}
```

Then use `mcp__beads__*` functions instead of CLI commands.

### Managing AI-Generated Planning Documents

AI assistants often create planning and design documents during development:
- PLAN.md, IMPLEMENTATION.md, ARCHITECTURE.md
- DESIGN.md, CODEBASE_SUMMARY.md, INTEGRATION_PLAN.md
- TESTING_GUIDE.md, TECHNICAL_DESIGN.md, and similar files

**Best Practice: Use a dedicated directory for these ephemeral files**

**Recommended approach:**
- Create a `history/` directory in the project root
- Store ALL AI-generated planning/design docs in `history/`
- Keep the repository root clean and focused on permanent project files
- Only access `history/` when explicitly asked to review past planning

**Example .gitignore entry (optional):**
```
# AI planning documents (ephemeral)
history/
```

**Benefits:**
- ✅ Clean repository root
- ✅ Clear separation between ephemeral and permanent documentation
- ✅ Easy to exclude from version control if desired
- ✅ Preserves planning history for archeological research
- ✅ Reduces noise when browsing the project

## Implementation Guidelines

### User Documentation

- **README.md**: High-level overview, installation instructions, quick start guide
- **docs/**: Detailed user guides, API reference, configuration options, best practices, architecture docs
- **Format**: Markdown files with consistent structure and formatting
- **Coverage**: Public APIs, usage examples, tutorials, breaking changes that affect users
- **Examples**: Working code samples in `examples/` directory with progressive complexity
- **AI-Friendly**: Complete runnable examples, clear patterns, searchable structure, error handling examples

### Developer Documentation

- **Inline comments**: EmmyLua annotations for LSP hover documentation
- **Code structure**: Clear module organization with descriptive names
- **Internal APIs**: Documented for maintenance and extension

### Testing

- **Framework**: Use luatest framework (`make deps` to install)
- **Coverage**: 100% statement coverage for all code
- **Structure**: `tests/` directory mirroring `lua/` structure
- **Naming**: `test_filename.lua`, individual tests with `::` syntax (e.g., `tests/test_tokenizer.lua::test_literal_string`)
- **Scope**: Unit tests, integration tests, performance tests
- **Template testing**: Both compilation and runtime rendering
- **Safety**: Mock unsafe operations (file I/O, network, etc.)
- **Mandatory**: Tests required for all code changes
- **Run tests**: `luatest tests/` or `luatest tests/test_specific.lua`

### Linting/Quality

- **Primary linting**: Lua LSP with .luarc.json for static analysis
- **Code quality**: No unused variables, consistent naming, proper error handling
- **Security**: Scan for common vulnerabilities (command injection, etc.)
- **Type safety**: Use EmmyLua annotations where beneficial
- **Blocking**: Must pass before commits
- **False positives**: Suppress with comments (e.g., `-- luacheck: ignore`)
- **Reasonable rules**: Not overly strict, focus on real issues

### Formatting

- **Lua**: `stylua lua/` (4 spaces, 88 columns, Unix line endings per .stylua.toml)
- **C**: `make format` (clang-format with LLVM style, 4-space indentation)
- **Mandatory**: Code must be formatted before commits
- **Editor integration**: Configure editors to format on save

## Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ✅ Store AI planning docs in `history/` directory
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems
- ❌ Do NOT clutter repo root with planning documents

For more details, see README.md and QUICKSTART.md.

No Cursor or Copilot rules found.</content>
<parameter name="filePath">/home/matt/Work/nibiru/AGENTS.md
