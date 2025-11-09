# Nibiru Template Engine - Current State & Design

## Overview
The Nibiru template engine is designed to be AI-optimized with clear, predictable syntax and compile-time validation. It features components, expressions, control flow, and other advanced templating capabilities.

## Current Status
- ✅ **Design Complete**: All syntax and features designed
- 🔄 **Implementation Ready**: Template engine implementation pending
- 📋 **Next**: Complete component-based template engine (nibiru-dgw)

## Key Design Decisions

### Syntax Philosophy
- `{{ }}` for expressions and variables
- `{% %}` for control flow statements
- `{-- --}` for comments
- Clear separation between logic and output

### Component System
- Capital naming: `<Button>` vs `<button>`
- Inlined compilation (no runtime function calls)
- XML-style syntax with self-closing support
- Compile-time validation with error suggestions

### Expression Features
- Math operations: `{{count + 1}}`
- String operations: `{{first .. " " .. last}}`
- Safe navigation: `{{user?.name}}`
- Dynamic access: `{{user[dynamic_key]}}`
- Function calls: `{{math.floor(price)}}`

### Control Flow
- If statements: `{% if condition %} content {% endif %}`
- Loops: `{% for item in items %} content {% endfor %}`
- Full Lua expression support in conditions

### Filters & Pipelines
- Pipeline operator: `{{value |> filter(args)}}`
- Chaining: `{{name |> default("Anon") |> uppercase}}`
- Function-based: Translates to `filter(value, args)`

### Advanced Features
- Template inheritance: `{% extends %}`, `{% block %}`
- Whitespace control: `{{- expr -}}`
- Comments: `{-- multi-line comments --}`

## Implementation Plan

### Phase 1: Core Infrastructure
- Extend tokenizer for new syntax
- Build parser for expressions and statements
- Create component registry
- Implement basic compilation

### Phase 2: Features
- Add expression evaluation
- Implement control flow
- Add component inlining
- Implement filters and pipelines

### Phase 3: Advanced Features
- Template inheritance
- Whitespace control
- Error handling and validation

### Phase 4: Testing & Polish
- 100% test coverage
- Performance optimization
- Documentation

## Files to Modify
- `lua/nibiru/template.lua` - Main template engine
- `lua/nibiru/tokenizer.lua` - May need extensions
- `tests/test_template.lua` - Test suite

## Dependencies
- Design complete (nibiru-7ld ✅)
- luatest for testing
- Existing tokenizer foundation

## Quality Requirements
- 100% statement coverage
- Compile-time validation
- Performance benchmarks
- Comprehensive error messages
- AI-friendly patterns

## Next Steps
1. Claim nibiru-dgw issue
2. Start with core infrastructure
3. Implement features incrementally
4. Test thoroughly at each step