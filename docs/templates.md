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
- **Name**: A unique identifier (use CapitalCase to distinguish from HTML elements)
- **Template String**: The component's template content

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

Pass data to components using attributes:

```lua
Template.component("UserCard", [[
<div class="user-card">
  <h3>{{name}}</h3>
  <p class="role">{{role}}</p>
  <Button class="btn-sm" text="Edit" type="button"/>
</div>
]])

-- Usage
local card = Template("user_card_template")
print(card({
  name = "John Doe",
  role = "Administrator"
}))
```

### Component vs HTML Distinction

- **Components**: Start with capital letters (`<Button>`, `<UserCard>`)
- **HTML Elements**: Use lowercase (`<div>`, `<button>`, `<input>`)

This naming convention ensures clear separation between custom components and standard HTML elements.

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