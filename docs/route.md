# Routing

Nibiru's routing system provides a flexible way to map HTTP requests to responder functions based on URL patterns and HTTP methods.

## Overview

Routes define how incoming HTTP requests are handled. Each route consists of:
- A URL path pattern (with optional parameters)
- An HTTP method (or methods)
- A responder function that processes the request
- An optional unique name for identification and lookup

## Basic Route Syntax

Routes are created using the `Route` class:

```lua
local Route = require("nibiru.route")
local http = require("nibiru.http")

local route = Route("/hello", function(request)
    return http.Response(200, "Hello World!")
end)
```

You can optionally provide a unique name for the route:

```lua
local route = Route("/hello", function(request)
    return http.Response(200, "Hello World!")
end, "hello_route")
```

## Path Patterns

Route paths support static segments and dynamic parameters:

### Static Paths
```lua
Route("/users", function(request) ... end)
-- Matches: /users
```

### Parameters

Parameters are defined using curly braces with required type converters:

```lua
Route("/users/{id:string}", function(request, id) ... end)
-- Matches: /users/123, /users/abc, etc.
```

### Typed Parameters

Use type converters for automatic parameter conversion:

```lua
Route("/users/{id:integer}", function(request, id) ... end)
-- Matches: /users/123 (id becomes number 123)
```

Available converters:

- `string` - Any characters except `/`
- `integer` - Whole numbers (converted to Lua number)

## HTTP Methods

By default, routes accept GET requests. Specify other methods explicitly:

```lua
Route("/users", function(request) ... end, nil, {"GET", "POST"})
```

Or with a route name:

```lua
Route("/users", function(request) ... end, "users_route", {"GET", "POST"})
```

Supported methods: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`

## Route Names

Routes can optionally be given unique names for identification:

```lua
Route("/users", function(request) ... end, "users_index")
Route("/users/{id:integer}", function(request, id) ... end, "users_show")
```

**Important:** Route names must be unique within an application. The Application will throw an error if duplicate names are detected during initialization.

Routes without names function identically but are not included in the application's route lookup table.

## Responder Functions

Responder functions receive the request object and extracted parameters:

```lua
Route("/users/{id:integer}", function(request, user_id)
    -- request: HTTP request object
    -- user_id: extracted integer parameter
    return http.Response(200, string.format('{"user_id": %d}', user_id), "application/json")
end)
```

## Advanced Examples

### Multiple Parameters

```lua
Route("/users/{user_id:integer}/posts/{post_id:integer}",
      function(request, user_id, post_id)
    -- Handle request for specific user post
end, {"GET"})
```

### Method-Specific Routes

```lua
Route("/users/{id:integer}", function(request, id)
    -- GET: retrieve user
    return get_user(id)
end, {"GET"})

Route("/users/{id:integer}", function(request, id)
    -- PUT: update user
    local data = request.body
    return update_user(id, data)
end, {"PUT"})
```

## Error Handling

Routes don't handle errors directly - that's the responsibility of the responder function. Common patterns:

```lua
Route("/users/{id:integer}", function(request, id)
    local user = find_user(id)
    if not user then
        return http.not_found("User not found")
    end
    return http.ok(user, "application/json")
end)
```

## API Reference

### Route(path, responder, name, methods)

Creates a new route.

**Parameters:**
- `path` (string): URL path pattern with optional parameters
- `responder` (function): Function that takes `(request, ...params)` and returns a response
- `name` (string, optional): Unique name for the route. Must be unique across all routes in an application
- `methods` (table, optional): Array of allowed HTTP methods. Defaults to `{"GET"}`

**Returns:** Route instance

**Notes:**
- Route names must be unique within an application. Attempting to create an application with duplicate route names will result in an error.
- Routes without names are not included in the application's route lookup table.

### Route:matches(method, path)

Checks if the route matches a request.

**Parameters:**
- `method` (string): HTTP method (GET, POST, etc.)
- `path` (string): Request path

**Returns:** Match constant (`NO_MATCH`, `MATCH`, or `NOT_ALLOWED`)

### Route:run(request)

Executes the route's responder with extracted parameters.

**Parameters:**
- `request` (Request): HTTP request object

**Returns:** Response object from the responder function

## URL Generation

Routes support URL generation through the `url_for` instance method, which performs reverse route matching by constructing URLs from route parameters.

### Basic URL Generation

Use the `url_for` method to generate URLs for routes:

```lua
local Route = require("nibiru.route")

-- Define a route with parameters
local blog_route = Route("/blog/{year:integer}/{slug:string}", handler, "blog_post")

-- Generate a URL
local url = blog_route:url_for(2024, "my-article-title")
-- Returns: "/blog/2024/my-article-title"
```

### Parameter Requirements

The `url_for` method expects exactly the same number of arguments as there are parameters in the route pattern:

```lua
-- Route with two parameters: year (integer) and slug (string)
local route = Route("/blog/{year:integer}/{slug:string}", handler)

route:url_for(2024, "hello-world")        -- ✅ Correct
route:url_for(2024)                       -- ❌ Error: missing slug parameter
route:url_for(2024, "hello", "extra")     -- ❌ Error: too many parameters
```

### Parameter Validation

- **Nil values**: All parameters must be non-nil
- **Type checking**: Parameters are validated according to their declared types
- **Arity checking**: The number of arguments must match the route's parameter count

```lua
route:url_for(2024, nil)     -- ❌ Error: nil parameter not allowed
route:url_for("2024", "ok")  -- ❌ Error: year must be integer-compatible
```

### Supported Parameter Types

The method supports the same parameter types as route matching:

- `string`: Any characters except `/`
- `integer`: Whole numbers (automatically converted)

### Error Handling

`url_for` provides clear error messages for common issues:

- `"Route requires X parameters, got Y"` - Wrong number of arguments
- `"Parameter X cannot be nil"` - Nil value provided
- `"Parameter X must be a valid Y"` - Type conversion failed

### Use Cases

URL generation is commonly used in templates and responders:

```lua
-- In a responder
function list_posts(request)
    local posts = get_posts()
    for _, post in ipairs(posts) do
        post.url = blog_route:url_for(post.year, post.slug)
    end
    return render("posts.html", { posts = posts })
end

-- In templates (once route function is implemented)
<a href="{{ route('blog_post', post.year, post.slug) }}">Read more</a>
```

### API Reference

#### Route:url_for(...params)

Generates a URL by substituting parameters into the route pattern.

**Parameters:**
- `...params`: Variable number of parameters matching the route's pattern

**Returns:** `string` - The generated URL path

**Errors:**
- When parameter count doesn't match route requirements
- When any parameter is nil
- When parameter types don't match the route definition

**Examples:**
```lua
-- Simple route
Route("/users/{id:integer}"):url_for(123)                    -- "/users/123"

-- Multiple parameters
Route("/blog/{year:integer}/{month:integer}/{slug:string}"):url_for(2024, 12, "title")  -- "/blog/2024/12/title"

-- No parameters
Route("/home"):url_for()                                       -- "/home"
```
