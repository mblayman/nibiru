# Nibiru Templates

Nibiru provides the core control flow needed for template engines and a powerful component-based template system optimized for AI development. Templates compile to efficient Lua functions with predictable structure and minimal syntax.

## Control Flow

Nibiru templates support conditional rendering using `{% if condition %}...{% endif %}` blocks.

### Basic Conditional Rendering

Use `{% if condition %}` to conditionally render content:

```lua
local template = Template([[
<div>
  <h1>Welcome</h1>
  {% if user.is_admin %}
  <p>You have admin privileges.</p>
  {% endif %}
</div>
]])

local result = template({
  user = { is_admin = true }
})
```

Output:
```html
<div>
  <h1>Welcome</h1>
  <p>You have admin privileges.</p>
</div>
```

When the condition is false, the content is not rendered:

```lua
local result = template({
  user = { is_admin = false }
})
```

Output:
```html
<div>
  <h1>Welcome</h1>
</div>
```

### Conditional Expressions

Conditions support the full range of Lua expressions:

```lua
{% if user.age >= 18 %}
<p>You are an adult.</p>
{% endif %}

{% if user.role == "admin" or user.role == "moderator" %}
<p>You have elevated permissions.</p>
{% endif %}

{% if not user.banned %}
<p>Welcome back!</p>
{% endif %}
```

### Complex Conditions

Combine multiple conditions using logical operators:

```lua
{% if user.logged_in and user.subscription.active %}
<p>Access granted to premium content.</p>
{% endif %}

{% if count > 0 or show_empty %}
<p>Total items: {{count}}</p>
{% endif %}
```

### Property Access in Conditions

Access nested properties and use default values:

```lua
{% if user.profile.settings.notifications %}
<p>Notifications enabled.</p>
{% endif %}

{% if user.name or "Anonymous" == "Alice" %}
<p>Hello Alice!</p>
{% endif %}
```

### Control Flow in Components

Control flow works within component definitions:

```lua
Template.component("UserStatus", [[
<div class="status">
  {% if user.online %}
  <span class="online">● Online</span>
  {% else %}
  <span class="offline">● Offline</span>
  {% endif %}
</div>
]])
```

### Error Handling

Invalid `{% if %}` syntax will result in clear error messages:

- `{% if %}` - Missing condition
- `{% if condition %}` without matching `{% endif %}` - Unclosed block
- Nested `{% if %}` blocks - Not yet supported (will be added in future versions)

## Iteration with For Loops

Nibiru templates support iteration over arrays and tables using `{% for variable in expression %}...{% endfor %}` blocks.

### Basic Array Iteration

Use `{% for item in items %}` to iterate over arrays:

```lua
local template = Template([[
<ul>
  {% for item in items %}
  <li>{{ item.name }} - ${{ item.price }}</li>
  {% endfor %}
</ul>
]])

local result = template({
  items = {
    { name = "Apple", price = 1.50 },
    { name = "Banana", price = 0.75 },
    { name = "Orange", price = 2.00 }
  }
})
```

Output:
```html
<ul>
  <li>Apple - $1.5</li>
  <li>Banana - $0.75</li>
  <li>Orange - $2</li>
</ul>
```

### Key-Value Iteration

Use `{% for key, value in pairs(data) %}` to iterate over table key-value pairs:

```lua
local template = Template([[
<dl>
  {% for key, value in pairs(user) %}
  <dt>{{ key }}</dt>
  <dd>{{ value }}</dd>
  {% endfor %}
</dl>
]])

local result = template({
  user = {
    name = "Alice",
    age = 30,
    role = "admin"
  }
})
```

Output:
```html
<dl>
  <dt>name</dt>
  <dd>Alice</dd>
  <dt>age</dt>
  <dd>30</dd>
  <dt>role</dt>
  <dd>admin</dd>
</dl>
```

### Indexed Array Iteration

Use `{% for index, item in ipairs(items) %}` to access both index and value:

```lua
local template = Template([[
<table>
  <tr><th>#</th><th>Item</th><th>Price</th></tr>
  {% for index, item in ipairs(items) %}
  <tr>
    <td>{{ index }}</td>
    <td>{{ item.name }}</td>
    <td>${{ item.price }}</td>
  </tr>
  {% endfor %}
</table>
]])

local result = template({
  items = {
    { name = "Apple", price = 1.50 },
    { name = "Banana", price = 0.75 }
  }
})
```

Output:
```html
<table>
  <tr><th>#</th><th>Item</th><th>Price</th></tr>
  <tr>
    <td>1</td>
    <td>Apple</td>
    <td>$1.5</td>
  </tr>
  <tr>
    <td>2</td>
    <td>Banana</td>
    <td>$0.75</td>
  </tr>
</table>
```

### Empty Collections

For loops handle empty collections gracefully - no output is generated:

```lua
local template = Template([[
{% for item in items %}
<p>{{ item }}</p>
{% endfor %}
{% if #items == 0 %}
<p>No items found.</p>
{% endif %}
]])

local result = template({ items = {} })
```

Output:
```html
<p>No items found.</p>
```

### Nested For Loops

For loops can be nested for complex data structures:

```lua
local template = Template([[
{% for category in categories %}
<h2>{{ category.name }}</h2>
<ul>
  {% for item in category.items %}
  <li>{{ item }}</li>
  {% endfor %}
</ul>
{% endfor %}
]])

local result = template({
  categories = {
    { name = "Fruits", items = {"Apple", "Banana"} },
    { name = "Vegetables", items = {"Carrot", "Broccoli"} }
  }
})
```

Output:
```html
<h2>Fruits</h2>
<ul>
  <li>Apple</li>
  <li>Banana</li>
</ul>
<h2>Vegetables</h2>
<ul>
  <li>Carrot</li>
  <li>Broccoli</li>
</ul>
```

### Expression Support

For loop expressions support the same syntax as if conditions:

```lua
{% for user in users %}
{% if user.active %}
<div class="user">{{ user.name }}</div>
{% endif %}
{% endfor %}

{% for key, value in pairs(data or {}) %}
<p>{{ key }}: {{ value }}</p>
{% endfor %}
```

### Error Handling

Invalid `{% for %}` syntax will result in clear error messages:

- `{% for %}` - Missing variable and expression
- `{% for item %}` - Missing `in` keyword and expression
- `{% for item in %}` - Missing expression after `in`
- `{% for item in items %}` without matching `{% endfor %}` - Unclosed block
- `{% endfor %}` without matching `{% for %}` - Orphaned endfor

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
```

Output:
```html
<div class="welcome">
  <h1>Hello Alice!</h1>
  <button>Get Started</button>
</div>
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
