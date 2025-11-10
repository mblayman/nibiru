# Nibiru Templates

Nibiru provides a powerful component-based template system optimized for AI development. Templates compile to efficient Lua functions with predictable structure and minimal syntax.

## Component System

The template system is built around reusable components that can be composed together. Components are registered globally and can reference each other without explicit imports.

### Component Registration

Register components using the `component` method:

```lua
local Template = require("nibiru.template")

-- Register a reusable Button component.
Template.component("Button", [[
<button class="{{class}}" type="{{type or 'button'}}">
  {{text}}
</button>
]])

-- Register an Icon component.
Template.component("Icon", [[
<i class="icon icon-{{name}}"></i>
]])
```

Components are registered with:
- **Name**: A unique identifier (must start with a capital letter to distinguish from HTML elements)
- **Template String**: The component's template content

Component names must start with a capital letter. Attempting to register a component with a lowercase name will result in an error.

### Basic Component Usage

Use registered components in templates with XML-style syntax:

```lua
-- Register a form component that uses Button.
Template.component("LoginForm", [[
<form action="/login" method="post">
  <div class="form-group">
    <label>Email:</label>
    <input type="email" name="email" required/>
  </div>
  <div class="form-group">
    <label>Password:</label>
    <input type="password" name="password" required/>
  </div>
  <Button class="primary" type="submit" text="Sign In"/>
</form>
]])
```

### Component Props

Pass data to components using attributes. Attributes can contain static values or dynamic expressions:

```lua
Template.component("UserCard", [[
<div class="user-card">
  <h3>{{name}}</h3>
  <p class="role">{{role}}</p>
  <Button class="btn-sm" text="Edit" type="button"/>
</div>
]])

-- Usage
local template = Template('<UserCard name=user.name role=user.role/>')
print(template({
  user = { name = "John Doe", role = "Administrator" }
}))
```

#### Attribute Syntax

Attributes support two formats:

- **Quoted strings**: `attr="value"` or `attr='value'`
- **Expressions**: `attr=expression` (unquoted, supports Lua expressions)

```lua
-- Examples
<Button text="Click me" disabled=false/>
<Button class="primary" size=size or "medium"/>
<UserCard name=user.name role=user.role or "Guest"/>
```

#### Expression Syntax

Expressions in `{{ }}` blocks and attributes support:
- Variable access: `user.name`, `item.value`
- Operators: `+`, `-`, `*`, `/`, `==`, `~=`, `>`, `<`, `>=`, `<=`
- Logical operators: `and`, `or`, `not`
- Literals: strings `"hello"`, numbers `123`, booleans `true`/`false`
- Property access: `object.property`, `array[1]`
- Default values: `value or "default"`

```lua
{{ user.name or "Anonymous" }}
{{ count > 0 and "items" or "item" }}
{{ item.price * 1.1 }}
```

### Component Syntax Requirements

Components must use self-closing syntax:

```lua
<!-- Correct -->
<Button text="Save"/>
<UserCard name="John"/>

<!-- Incorrect - will cause errors -->
<Button>Save</Button>
<UserCard>Content</UserCard>
```

### Component vs HTML Distinction

- **Components**: Start with capital letters (`<Button>`, `<UserCard>`)
- **HTML Elements**: Use lowercase (`<div>`, `<button>`, `<input>`)

This naming convention ensures clear separation between custom components and standard HTML elements.

### Error Handling

The template system provides clear error messages for common issues:

- **Invalid component names**: Component names must start with capital letters
- **Duplicate registration**: Cannot register the same component name twice
- **Malformed syntax**: Invalid component tags or attributes
- **Missing components**: Using unregistered component names

```lua
-- These will cause errors:
Template.component("button", "...")  -- lowercase name
Template.component("Button", "...")   -- register
Template.component("Button", "...")   -- duplicate
Template('<button text="ok"/>')       -- lowercase treated as HTML
Template('<Unknown/>')                -- unregistered component
```

### Rendering Templates

Compile and render templates with context data:

```lua
local Template = require("nibiru.template")

-- Register components.
Template.component("Button", [[<button>{{text}}</button>]])

-- Create and render a template
local template = Template([[
<div class="welcome">
  <h1>Hello {{user.name}}!</h1>
  <Button text="Get Started"/>
</div>
]])

local result = template({
  user = { name = "Alice" }
})
-- Output: <div class="welcome"><h1>Hello Alice!</h1><button>Get Started</button></div>
```

Components are inlined during compilation for maximum performance - no runtime component resolution overhead.

## Advanced Features

### Component Composition

Components can use other components, enabling complex UI hierarchies:

```lua
Template.component("Button", [[<button>{{text}}</button>]])
Template.component("Form", [[
<form>
  <input type="text" name="query"/>
  <Button text="Search"/>
</form>
]])
```

### Default Values

Use Lua expressions for default values in component attributes:

```lua
Template.component("Button", [[
<button class="{{class or 'btn'}}" type="{{type or 'button'}}">
  {{text}}
</button>
]])
```

## Testing and Development

### Clearing Components

For testing, you can clear all registered components:

```lua
Template.clear_components()  -- Remove all registered components
```

### Template Compilation

Templates are compiled to Lua functions for optimal performance. The compilation process:

1. Parses template syntax into tokens
2. Resolves component references
3. Generates efficient Lua code
4. Returns a callable function

```lua
local template = Template('<Button text="Hello"/>')
-- template is now a compiled function ready for rendering

-- For debugging, templates also expose the generated Lua code:
print(template.code)  -- Shows the compiled Lua source
```

### Error Messages

All errors occur at render time (not compile time) to provide better debugging:

- `"Component 'X' is not registered"` - Using unknown component
- `"malformed attribute"` - Invalid attribute syntax
- `"malformed component tag"` - Invalid component syntax