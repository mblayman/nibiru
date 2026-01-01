# nibiru

A way out there idea deserves a way out there name

## Quick Start

Get started with Nibiru in minutes:

1. Install: `luarocks install nibiru`
2. Create your first app following the [Getting Started Guide](docs/getting-started.md)
3. Run: `nibiru run myapp:app`

📖 **[Full Documentation](docs/getting-started.md)** | 📋 **[Command Reference](docs/commands.md)**

## Plan

Write a Lua webserver from scratch. Only use code that I have written myself.

## Unknowns

- What should I do for unit testing C code?
- Should I add an acceptance test?
- How could I integrate valgrind and other C quality checks? I know nothing here.
- How would I deal with Unicode? http://lua-users.org/wiki/LuaUnicode

## Inspiration

Async is powerful, but I don't want to deal with it.
Instead, I think I want to stick with WSGI over ASGI.
[WSGI spec](https://peps.python.org/pep-3333/)

## Architecture

- A C-based server should load a callable using a Gunicorn style
  of `module.path:app` and default to `app` being the callable
  so that `module.path` can be used.
- Ideally, the server should have a pool of workers that can receive data
  from an accepted socket.
  Initially, I think I can operate from a forking model so that I don't over-optimize.
- If I want to do HTTP parsing in Lua,
  calling the application callable will have to be delegated to the Lua code side
  of the server.
- The C side can deal with network connections and send all the inbound bytes 
  to the Lua side.
- The Lua side can construct the whole response so that the C side only has to flush
  the bytes over the network.
- Over time, I could move HTTP parsing to the C side to improve performance.

## Resources

- Here is a network guide: https://beej.us/guide/bgnet/html//index.html

These are the resources that I haven't read much of yet:

- [LuaSocket](https://github.com/lunarmodules/luasocket/blob/master/src/io.c#L11)
- Maybe I should read [Programming in Lua, 4th Edition](https://www.goodreads.com/book/show/55647909-programming-in-lua-fourth-edition-by-roberto-ierusalimschy-lua-org?ref=nav_sb_ss_2_18)
- Apparently, http://lua.sqlite.org/index.cgi/home is a thing.
- https://redbean.dev/ is in the same space. Lots of interesting ideas here like TLS, gzip, SQLite
- What lesson can I learn from Gunicorn? What is the architecture?

## Making releases

These are notes to help me remember how to cut a release for LuaRocks.

```
luarocks new_version nibiru-dev-1.rockspec <new version like 0.2>
# Upload expects branch name of v0.1 format
git tag -a v0.2 -m 0.2
# The upload command will build a source rock locally.
# Example
luarocks upload rockspecs/nibiru-0.1-1.rockspec --api-key=$LUAROCKS_KEY
```

