# Application

The Application class serves as the main entry point for Nibiru web applications, coordinating routing, configuration, and request handling according to the WSGI interface.

## Overview

An Application instance:

- Maintains a collection of routes for request matching
- Provides a lookup table for named routes
- Loads and manages application configuration
- Acts as a WSGI callable for server integration
- Generates URLs through named route reverse lookup

## Basic Usage

Create an application with routes:

```lua
local Application = require("nibiru.application")
local Route = require("nibiru.route")
local http = require("nibiru.http")

local routes = {
    Route("/hello", function(request)
        return http.Response(200, "Hello World!")
    end, "hello"),

    Route("/users/{id:integer}", function(request, user_id)
        return http.Response(200, string.format("User: %d", user_id))
    end, "user_detail")
}

local app = Application(routes)
```

## Route Management

### Named Routes

Routes can be given unique names for identification and URL generation:

```lua
local user_route = Route("/users/{id:integer}", handler, "user_detail")
local post_route = Route("/posts/{slug:string}", handler, "post_detail")
```

Named routes are automatically added to the application's lookup table during initialization.

## Configuration

Applications automatically load configuration from a config file:

```lua
-- Load from default location (inferred from boot parameters)
local app = Application(routes)

-- Load from specific config file
local app = Application(routes, "path/to/config.lua")
```

See [Configuration](config.md) for details on config file structure.

## WSGI Interface

Applications implement the WSGI callable interface for web server integration:

```lua
function app(environ, start_response)
    -- Handle request and return response
end
```

## URL Generation

The `url_for` method provides reverse route lookup, generating URLs from named routes and their parameters.

### Basic URL Generation

Generate URLs for named routes:

```lua
local app = Application({
    Route("/users/{id:integer}", handler, "user_detail"),
    Route("/posts/{year:integer}/{slug:string}", handler, "post_detail")
})

-- Generate URLs
local user_url = app:url_for("user_detail", 123)           -- "/users/123"
local post_url = app:url_for("post_detail", 2024, "title")  -- "/posts/2024/title"
```

### Parameter Requirements

The method requires exactly the same number of arguments as the route's parameter count:

```lua
-- Route with one parameter
app:url_for("user_detail", 123)        -- ✅ Correct
app:url_for("user_detail")             -- ❌ Error: missing parameter
app:url_for("user_detail", 123, 456)   -- ❌ Error: too many parameters

-- Route with two parameters
app:url_for("post_detail", 2024, "title")  -- ✅ Correct
app:url_for("post_detail", 2024)           -- ❌ Error: missing slug parameter
```

### Error Handling

`url_for` provides clear error messages:

- `"Unknown route name: Z"` - Route name not found

## API Reference

### Application(routes, config_path)

Creates a new application instance.

**Parameters:**
- `routes` (table, optional): Array of Route instances. Defaults to empty array
- `config_path` (string, optional): Path to config file. Auto-detected if not provided

**Returns:** Application instance

**Notes:**
- Route names must be unique. Duplicate names cause initialization errors
- Configuration is loaded automatically during construction
- Template loader is initialized with config settings

### Application:url_for(route_name, ...params)

Generates a URL by looking up a named route and delegating to its `url_for` method.

**Parameters:**
- `route_name` (string): Name of the route to generate URL for
- `...params`: Variable number of parameters matching the route's pattern

**Returns:** `string` - The generated URL path

**Errors:**
- When route name is not found in the application's route lookup table
- When parameter count doesn't match route requirements
- When any parameter is nil
- When parameter types don't match the route definition

**Examples:**
```lua
local app = Application({
    Route("/users/{id:integer}", handler, "user_detail"),
    Route("/blog/{year:integer}/{slug:string}", handler, "blog_post")
})

app:url_for("user_detail", 123)                    -- "/users/123"
app:url_for("blog_post", 2024, "my-article")       -- "/blog/2024/my-article"
```

### Application:find_route(method, path)

Finds a matching route for an HTTP request.

**Parameters:**
- `method` (string): HTTP method (GET, POST, etc.)
- `path` (string): Request path

**Returns:** `match, route`
- `match` (Match): Route match status (`NO_MATCH`, `MATCH`, or `NOT_ALLOWED`)
- `route` (Route, optional): The matching route instance, or nil

### Application.__call(environ, start_response)

WSGI callable interface. Processes HTTP requests and returns responses.

**Parameters:**
- `environ` (table): WSGI environment dictionary
- `start_response` (function): WSGI start_response callable

**Returns:** Iterator over response body content
