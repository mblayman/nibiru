# Command Reference

This document describes all available nibiru commands and their options.

## Overview

Nibiru provides a command-line interface for running web applications. The main command is `nibiru run` for starting the web server.

## Commands

### `nibiru run`

Start the Nibiru web server with a WSGI application.

```bash
nibiru run [--workers N] [--static DIR] [--static-url URL] <app> [port]
```

**Arguments:**

- `<app>`: WSGI application in the format `module.path:callable` (e.g., `myapp:app`)
  - `module.path` - Lua module path to require
  - `callable` - Name of the WSGI callable (defaults to `app` if omitted)
- `[port]` (optional): Port to listen on (defaults to 8080)

**Options:**

- `--workers N`: Number of worker processes to spawn (default: 2)
  - Can be specified as `--workers=N` or `--workers N`
  - Must be a positive integer
- `--static DIR`: Directory to serve static files from (default: "static")
  - Relative paths are resolved from the current working directory
  - Static files are served under the URL prefix specified by `--static-url`
- `--static-url URL`: URL prefix for static files (default: "/static")
  - Requests to URLs starting with this prefix will be served from the static directory
  - Must start with "/" and not contain ".." for security

**Examples:**

```bash
# Basic usage with default settings
nibiru run myapp:app

# Specify port
nibiru run myapp:app 3000

# Run with 4 worker processes
nibiru run --workers 4 myapp:app

# Alternative syntax for workers
nibiru run --workers=4 myapp:app 3000

# Serve static files from ./assets under /files URL
nibiru run --static assets --static-url /files myapp:app

# Serve static files from absolute path
nibiru run --static /var/www/static myapp:app
```

**Configuration:**

The application can be configured via a `config.lua` file in the working directory. See [Configuration](config.md) for details.

**Static File Serving:**

Nibiru can serve static files efficiently using an async worker process. When a request URL matches the configured static URL prefix, it is served directly from the file system without invoking the Lua application.

- Files are served with appropriate MIME types based on file extensions
- Requests containing ".." in the path are rejected for security
- Only regular files are served; directories return 404
- The static worker uses an event loop for high-performance concurrent serving

This approach ensures static files don't block dynamic request processing.

## Error Handling

### Invalid Arguments

```bash
$ nibiru run
Usage: nibiru run [--workers N] [--static DIR] [--static-url URL] <app> [port]
  <app> is in format of: module.path:app
  --workers N: number of worker processes (default: 2)
  --static DIR: directory for static files (default: static)
  --static-url URL: URL prefix for static files (default: /static)
```

### Invalid Worker Count

```bash
$ nibiru run --workers=0 myapp:app
Error: --workers must be a positive integer
Usage: nibiru run [--workers N] [--static DIR] [--static-url URL] <app> [port]
```

### Module Not Found

```bash
$ nibiru run nonexistent:app
Starting nibiru with 2 worker(s)
Error: lua/nibiru/server/boot.lua:11: module 'nonexistent.app' not found
```

### Application Not Callable

```bash
$ nibiru run myapp:invalid
Starting nibiru with 2 worker(s)
Error: `invalid` is not a valid callable.
```

## Server Behavior

### Startup

When you run `nibiru run myapp:app`, the server:

1. Parses command line arguments
2. Loads the Lua module `myapp`
3. Extracts the `app` callable from the module
4. Validates the callable implements the WSGI interface
5. Starts listening on the specified port
6. Forks worker processes (default: 2)
7. Begins accepting connections

### Request Processing

- **Parent Process**: Binds listening socket and forks workers
- **Worker Processes**: Accept connections directly and execute your WSGI application
- **Load Distribution**: OS kernel serializes accept() calls across workers
- **Isolation**: Each worker runs in its own process with separate Lua state

### Shutdown

Send SIGTERM or SIGINT (Ctrl+C) to gracefully shut down all workers.

## Environment Variables

Nibiru respects these environment variables:

- `LUA_PATH`: Additional Lua module search paths
- `LUA_CPATH`: Additional Lua C module search paths

These are automatically set when running from a LuaRocks installation.

## Troubleshooting

### Port Already in Use

```
Error: Address already in use
```

- Another process is using the port
- Use `lsof -i :8080` to find what's using the port
- Specify a different port: `nibiru run myapp:app 3000`

### Module Loading Issues

Common problems:

- **Wrong module path**: Ensure the Lua file is in the require path
- **Syntax errors**: Check Lua syntax in your application file
- **Missing dependencies**: Ensure all required modules are installed

### Performance Issues

- **Single worker bottleneck**: Try `--workers 4` or more
- **Memory usage**: Monitor with system tools
- **Slow responses**: Check your application logic and database queries

## Examples

### Basic Hello World

Create `hello.lua`:

```lua
local Application = require("nibiru.application")
local Route = require("nibiru.route")
local http = require("nibiru.http")

local routes = {
    Route("/", function(request)
        return http.Response(200, "Hello, World!")
    end)
}

return Application(routes)
```

Run with:
```bash
nibiru run hello:app
```

### Production Deployment

```bash
# Production setup with more workers
nibiru run --workers 8 myapp:app 80
```

### Development with Custom Port

```bash
# Development on port 3000
nibiru run --workers 2 myapp:app 3000
```

## Related Documentation

- [Getting Started](getting-started.md) - Beginner tutorial
- [Application Guide](application.md) - Building applications
- [Configuration](config.md) - Application configuration
- [WSGI Interface](wsgi.md) - Server interface specification
