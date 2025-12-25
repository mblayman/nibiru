# Routing

Nibiru's routing system provides a flexible way to map HTTP requests to responder functions based on URL patterns and HTTP methods.

## Overview

Routes define how incoming HTTP requests are handled. Each route consists of:
- A URL path pattern (with optional parameters)
- An HTTP method (or methods)
- A responder function that processes the request

## Basic Route Syntax

Routes are created using the `Route` class:

```lua
local Route = require("nibiru.route")
local http = require("nibiru.http")

local route = Route("/hello", function(request)
    return http.Response(200, "Hello World!")
end)
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
Route("/users", function(request) ... end, {"GET", "POST"})
```

Supported methods: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`

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

### Route(path, responder, methods)

Creates a new route.

**Parameters:**
- `path` (string): URL path pattern with optional parameters
- `responder` (function): Function that takes `(request, ...params)` and returns a response
- `methods` (table, optional): Array of allowed HTTP methods. Defaults to `{"GET"}`

**Returns:** Route instance

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
