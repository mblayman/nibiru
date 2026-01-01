# Getting Started with Nibiru

Welcome to Nibiru! This guide will walk you through your first steps with building web applications using the Nibiru web framework for Lua.

## What is Nibiru?

Nibiru is a web framework and server for Lua that implements the WSGI interface. It provides:

- **Simple routing** - Define routes with path parameters and constraints
- **Template rendering** - Built-in template engine with inheritance
- **WSGI compatibility** - Standard interface for web applications
- **High performance** - C-based server with concurrent worker processes
- **Developer experience** - Clear error messages and easy debugging

## Prerequisites

Before getting started, ensure you have:

- Lua 5.1+ installed
- Basic familiarity with Lua programming
- A text editor or IDE

## Installation

Nibiru can be installed via LuaRocks:

```bash
luarocks install nibiru
```

Or clone and build from source:

```bash
git clone https://github.com/mblayman/nibiru.git
cd nibiru
make build
```

## Your First Application

Let's create a simple "Hello World" application.

### 1. Create Your App File

Create a file called `hello.lua`:

```lua
local Application = require("nibiru.application")
local Route = require("nibiru.route")
local http = require("nibiru.http")

-- Define a route that responds to GET requests at "/"
local function hello_handler(request)
    return http.Response(200, "Hello, World!")
end

-- Create routes table
local routes = {
    Route("/", hello_handler, "hello")
}

-- Create and return the application
return Application(routes)
```

### 2. Run the Server

Start the development server:

```bash
nibiru run hello:app
```

This starts the server on port 8080 by default. Visit `http://localhost:8080/` in your browser to see "Hello, World!"

## Understanding the Code

Let's break down what each part does:

### Routes

Routes map URLs to handler functions:

```lua
local routes = {
    Route("/", hello_handler, "hello")  -- path, handler, name
}
```

- **Path**: URL pattern to match (`"/"` matches the root URL)
- **Handler**: Function that processes the request and returns a response
- **Name**: Optional identifier for URL generation (more on this later)

### Handlers

Handlers are functions that receive a request and return a response:

```lua
local function hello_handler(request)
    return http.Response(200, "Hello, World!")
end
```

The `request` parameter contains information about the HTTP request (method, path, headers, etc.).

### Application

The Application ties everything together:

```lua
return Application(routes)
```

It manages routing, configuration, and provides the WSGI interface for the server.

## Adding More Routes

Let's add a few more routes to make our app more interesting:

```lua
local Application = require("nibiru.application")
local Route = require("nibiru.route")
local http = require("nibiru.http")

local function hello_handler(request)
    return http.Response(200, "Hello, World!")
end

local function about_handler(request)
    return http.Response(200, "About Nibiru: A web framework for Lua")
end

local function greet_handler(request, name)
    return http.Response(200, string.format("Hello, %s!", name))
end

local routes = {
    Route("/", hello_handler, "hello"),
    Route("/about", about_handler, "about"),
    Route("/greet/{name:string}", greet_handler, "greet")
}

return Application(routes)
```

Now you can visit:
- `http://localhost:8080/` - "Hello, World!"
- `http://localhost:8080/about` - "About Nibiru: A web framework for Lua"
- `http://localhost:8080/greet/Alice` - "Hello, Alice!"

### Path Parameters

Notice the `/greet/{name:string}` route. This uses path parameters:

- `{name:string}` captures a string value from the URL
- The captured value is passed as an argument to the handler function
- You can use `{param:integer}` for numbers or `{param}` for strings (string is default)

## Templates

Nibiru includes a powerful template engine. Let's create a templated response:

First, create a `templates` directory and add `base.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}Default Title{% endblock %}</title>
</head>
<body>
    <h1>{% block content %}{% endblock %}</h1>
    <footer>
        <p>Powered by Nibiru</p>
    </footer>
</body>
</html>
```

Then create `hello.html`:

```html
{% extends "base.html" %}

{% block title %}Hello Page{% endblock %}

{% block content %}
Hello, {{ name }}!
{% endblock %}
```

Update your handler to use templates:

```lua
local function greet_handler(request, name)
    return http.Response(200, {
        name = name
    }, "hello.html")
end
```

Now `/greet/Alice` will render a proper HTML page!

## Configuration

Nibiru applications can be configured via `config.lua`. Create this file in your project root:

```lua
return {
    server = {
        host = "127.0.0.1",
        port = 8080
    },
    templates = {
        directory = "templates"
    }
}
```

## Running with Multiple Workers

For better performance, run with multiple worker processes:

```bash
nibiru run --workers 4 hello:app
```

This starts 4 worker processes to handle concurrent requests.

## Next Steps

Now that you have a basic application running, explore:

- [Routing Guide](route.md) - Advanced routing patterns
- [Templates Guide](templates.md) - Template inheritance and features
- [Application Guide](application.md) - Application configuration and features
- [WSGI Interface](wsgi.md) - Understanding the server interface
- [Command Reference](commands.md) - All available commands

## Getting Help

- Check the documentation in the `docs/` directory
- Look at example applications in the `examples/` directory
- File issues on [GitHub](https://github.com/mblayman/nibiru)

Happy coding with Nibiru! 🚀</content>
<parameter name="filePath">/home/matt/Work/nibiru/docs/getting-started.md