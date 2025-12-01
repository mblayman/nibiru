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

## Filter Pipelines

Nibiru templates support filter pipelines using the `|>` operator to transform values through a series of functions. Filters provide a clean way to format, transform, and manipulate data directly in templates.

### Basic Filter Syntax

Use the pipeline operator `|>` to apply filters to values:

```lua
local template = Template([[
<div>
  <h1>{{ title |> uppercase }}</h1>
  <p>{{ description |> truncate(100) }}</p>
  <span>{{ count |> default("0") }} items</span>
</div>
]])

local result = template({
  title = "welcome to our site",
  description = "This is a very long description that should be truncated to prevent layout issues in the UI.",
  count = nil
})
```

Output:
```html
<div>
  <h1>WELCOME TO OUR SITE</h1>
  <p>This is a very long description that should be truncated to prevent layout issues in the UI.</p>
  <span>0 items</span>
</div>
```

### Chaining Multiple Filters

Apply multiple filters in sequence by chaining `|>` operators:

```lua
{{ name |> lowercase |> capitalize }}
{{ text |> strip |> truncate(50) |> uppercase }}
```

Filters are applied left-to-right, so `value |> filter1 |> filter2` is equivalent to `filter2(filter1(value))`.

### Built-in Filters

Nibiru provides several built-in filters for common transformations:

#### String Filters

- **`uppercase`**: Convert to uppercase
  ```lua
  {{ "hello" |> uppercase }}  -- "HELLO"
  ```

- **`lowercase`**: Convert to lowercase
  ```lua
  {{ "HELLO" |> lowercase }}  -- "hello"
  ```

- **`capitalize`**: Capitalize first letter, lowercase rest
  ```lua
  {{ "HELLO WORLD" |> capitalize }}  -- "Hello world"
  ```

- **`truncate(length)`**: Truncate string to specified length
  ```lua
  {{ "This is a long string" |> truncate(10) }}  -- "This is a l..."
  ```

#### Array/Object Filters

- **`length`**: Get length of array or string
  ```lua
  {{ items |> length }}        -- 5 (for array with 5 elements)
  {{ "hello" |> length }}       -- 5 (string length)
  ```

- **`first`**: Get first element of array
  ```lua
  {{ items |> first }}          -- items[1]
  ```

- **`last`**: Get last element of array
  ```lua
  {{ items |> last }}           -- items[#items]
  ```

- **`reverse`**: Reverse array elements
  ```lua
  {{ {1,2,3} |> reverse }}      -- {3,2,1}
  ```

#### Utility Filters

- **`default(value)`**: Return value or default if nil/false
  ```lua
  {{ user.name |> default("Anonymous") }}  -- user.name or "Anonymous"
  ```

- **`format(pattern)`**: Format value using string.format
  ```lua
  {{ 3.14159 |> format("%.2f") }}  -- "3.14"
  {{ count |> format("%d items") }} -- "5 items"
  ```

### Filter Arguments

Filters can accept arguments in parentheses:

```lua
{{ text |> truncate(50) }}
{{ number |> format("%.2f") }}
{{ value |> default("N/A") }}
```

Arguments can be literals, variables, or expressions:

```lua
{{ items |> truncate(max_length) }}
{{ price |> format("%.2f" .. currency) }}
```

### Using Filters in Component Attributes

Filters work in component attributes as well as template expressions:

```lua
Template.component("ProductCard", [[
<div class="product">
  <h3>{{ title |> capitalize }}</h3>
  <p class="price">${{ price |> format("%.2f") }}</p>
  <p class="desc">{{ description |> truncate(100) }}</p>
</div>
]])

-- Usage
local template = Template('<ProductCard title=product.title price=product.price description=product.desc/>')
```

### Custom Filters

Register custom filters for domain-specific transformations:

```lua
-- Register a custom filter
Template.register_filter("currency", function(value, symbol)
    symbol = symbol or "$"
    return string.format("%s%.2f", symbol, value)
end)

-- Use in templates
{{ 29.99 |> currency }}        -- "$29.99"
{{ 19.95 |> currency("€") }}    -- "€19.95"
```

Filter functions receive the value as the first argument, followed by any additional arguments passed in the template.

### Filter Function Signature

Custom filters should follow this pattern:

```lua
function my_filter(value, ...args)
    -- Transform the value
    return transformed_value
end
```

Filters should:
- Handle `nil` inputs gracefully
- Return appropriate default values when transformation fails
- Be pure functions (no side effects)

### Error Handling

Invalid filter usage results in clear error messages:

- **Unknown filters**: `"Unknown filter 'badfilter'"`
- **Wrong arguments**: `"Filter 'truncate' expects 1 argument, got 0"`
- **Non-callable filters**: `"Filter 'uppercase' is not a function"`

```lua
-- These will cause errors:
{{ value |> unknown_filter }}
{{ value |> truncate }}           -- missing required argument
{{ value |> truncate(10, 20) }}   -- too many arguments
```

### Performance Notes

- Filters are resolved at compile time, not runtime
- Filter pipelines generate efficient chained function calls
- No performance penalty for unused filters
- Custom filters should be efficient to avoid template rendering bottlenecks

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

 ### Advanced Features

#### Component Composition

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

#### Default Values

Use Lua expressions for default values in component attributes:

```lua
Template.component("Button", [[
<button class="{{class or 'btn'}}" type="{{type or 'button'}}">
  {{text}}
</button>
]])
```

## HTTP Response Rendering

The template system integrates seamlessly with Nibiru's HTTP response system, providing a convenient `render` function that returns complete HTTP responses for use in route responders.

### Basic Template Rendering

Import the `render` function and use it to render registered templates and return HTTP responses:

```lua
local render = require("nibiru.template").render

-- Register a template (typically done at app startup)
local Template = require("nibiru.template")
Template.register("welcome.html", [[
<div class="welcome">
  <h1>Hello {{user.name}}!</h1>
  <p>Welcome to {{site.name}}</p>
</div>
]])

-- In a route responder
function welcome_responder(request)
  return render("welcome.html", {
    user = { name = "Alice" },
    site = { name = "My App" }
  })
end
```

This automatically returns an HTTP 200 response with `text/html` content type.

### Custom Response Parameters

Customize the HTTP response by specifying content type, status code, and headers:

```lua
-- Custom content type and status
function api_response(request)
  return render("data.json", data, "application/json", 201)
end

-- With custom headers
function download_page(request)
  return render("report.html", report_data, "text/html", 200, {
    ["Content-Disposition"] = 'attachment; filename="report.html"'
  })
end
```

### Parameter Order

The `render` function parameters are ordered for common usage patterns:

```lua
render(template_name, context, content_type, status_code, headers)
```

- `template_name` (string): Name of the registered template
- `context` (table, optional): Variables for template rendering
- `content_type` (string, optional): MIME type (default: "text/html")
- `status_code` (integer, optional): HTTP status code (default: 200)
- `headers` (table, optional): Additional HTTP headers

### Error Handling

The `render` function will error if the template is not found:

```lua
-- This will throw an error
return render("nonexistent.html", {})
-- Error: Template 'nonexistent.html' not found
```

## Template Inheritance

Nibiru templates support template inheritance using `{% extends %}` and `{% block %}` directives. This allows you to create base templates with common structure and override specific sections in child templates.

### Basic Template Inheritance

Use `{% extends "base_template" %}` to inherit from a base template:

```lua
-- Base template (base.html)
local base_template = Template([[
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}Default Title{% endblock %}</title>
    {% block head %}{% endblock %}
</head>
<body>
    <header>
        <nav>{% block navigation %}{% endblock %}</nav>
    </header>

    <main>
        {% block content %}{% endblock %}
    </main>

    <footer>
        {% block footer %}© 2024 My Site{% endblock %}
    </footer>
</body>
</html>
]])

-- Child template extending base
local page_template = Template([[
{% extends "base.html" %}

{% block title %}My Page Title{% endblock %}

{% block navigation %}
<ul>
    <li><a href="/">Home</a></li>
    <li><a href="/about">About</a></li>
</ul>
{% endblock %}

{% block content %}
<h1>Welcome to My Page</h1>
<p>This is the main content of the page.</p>
{% endblock %}
]])

local result = page_template({})
```

Output:
```html
<!DOCTYPE html>
<html>
<head>
    <title>My Page Title</title>

</head>
<body>
    <header>
        <nav>
<ul>
    <li><a href="/">Home</a></li>
    <li><a href="/about">About</a></li>
</ul>
</nav>
    </header>

    <main>

<h1>Welcome to My Page</h1>
<p>This is the main content of the page.</p>

    </main>

    <footer>
        © 2024 My Site
    </footer>
</body>
</html>
```

### Block Directives

#### `{% block name %}` - Define overridable sections

Blocks define sections that can be overridden in child templates:

```lua
{% block header %}
<h1>Default Header</h1>
{% endblock %}
```

#### `{% block name %}...{% endblock %}` - Override parent blocks

Child templates can override parent blocks with new content:

```lua
{% block header %}
<h1>Custom Header for This Page</h1>
{% endblock %}
```

### Block Inheritance Rules

1. **Default Content**: If a child template doesn't override a block, the parent's content is used
2. **Complete Replacement**: Child blocks completely replace parent blocks (no merging)
3. **Nested Blocks**: Blocks can contain other template constructs (variables, components, control flow)
4. **Multiple Blocks**: Templates can have multiple blocks with unique names

### Advanced Block Usage

#### Conditional Block Content

Blocks can contain control flow and other template features:

```lua
{% block content %}
{% if user.logged_in %}
<h1>Welcome back, {{ user.name }}!</h1>
{% else %}
<h1>Welcome, Guest!</h1>
{% endif %}

{% for item in recent_items %}
<div class="item">{{ item.title }}</div>
{% endfor %}
{% endblock %}
```

#### Component Integration

Blocks work seamlessly with components:

```lua
-- Base template
{% block sidebar %}
<div class="sidebar">
    <UserMenu user=current_user/>
</div>
{% endblock %}

-- Child template
{% block sidebar %}
<div class="sidebar">
    <UserMenu user=current_user/>
    <AdBanner position="sidebar"/>
</div>
{% endblock %}
```

### Template Resolution

Templates are resolved by name when using `{% extends %}`:

1. **Named Templates**: Templates registered with `Template.register(name, template_string)`
2. **File-based**: Future support for loading templates from files
3. **Inline**: Templates can extend other inline templates

```lua
-- Register base template
Template.register("base.html", [[
<html>{% block content %}Default{% endblock %}</html>
]])

-- Extend registered template
local child = Template([[
{% extends "base.html" %}
{% block content %}Custom content{% endblock %}
]])
```

### Block Scope and Context

Blocks inherit the full template context:

```lua
local template = Template([[
{% extends "base.html" %}
{% block content %}
<p>User: {{ user.name }}</p>
<p>Items: {{ #items }}</p>
{% endblock %}
]])

template({
    user = { name = "Alice" },
    items = {1, 2, 3, 4, 5}
})
```

### Error Handling

Template inheritance provides clear error messages:

- **Missing Parent**: `"Template 'missing.html' not found"`
- **Circular Extends**: `"Circular template inheritance detected"`
- **Unclosed Blocks**: `"Unclosed block 'content'"`
- **Orphaned Endblock**: `"{% endblock %}` without matching block"

```lua
-- These will cause errors:
Template('{% extends "nonexistent.html" %}')  -- Template not found
Template('{% block content %}{% endblock %}{% block content %}')  -- Duplicate block names
Template('{% block content %}')  -- Unclosed block
Template('{% endblock %}')  -- Orphaned endblock
```

### Performance Notes

- **Compile-time Resolution**: Template inheritance is resolved during compilation, not runtime
- **Efficient Merging**: Child templates are merged with parent templates to generate optimized code
- **No Runtime Overhead**: Final compiled templates have no inheritance overhead
- **Caching**: Compiled templates can be cached for repeated use

### Best Practices

#### Block Naming Conventions

- Use descriptive names: `content`, `sidebar`, `header`, `footer`
- Use prefixes for complex layouts: `page_content`, `user_sidebar`
- Keep block names consistent across related templates

#### Content vs Layout

- **Base templates**: Define overall page structure and common elements
- **Child templates**: Focus on page-specific content and overrides
- **Components**: Use for reusable UI elements within blocks

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
