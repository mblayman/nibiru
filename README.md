# nibiru

A way out there idea deserves a way out there name

## Plan

Write a Lua webserver from scratch. Only use code that I have written myself.

Where to start?

- What lesson can I learn from Gunicorn? What is the architecture?

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
  of `module.path:application` and default to `application` being the callable
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
