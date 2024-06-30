# nibiru

A way out there idea deserves a way out there name

## Plan

Write a Lua webserver from scratch. Only use code that I have written myself.

Where to start?

- How can I open a socket in Lua? Will I have to use the C API?
- What lesson can I learn from Gunicorn? What is the architecture?
- I should steer clear of Zig for now. If I open up too many threads, I'll never get anywhere.
- I can study [LuaSocket](https://github.com/lunarmodules/luasocket/blob/master/src/io.c#L11) for inspiration.
- I should make a second program that just uses the Lua C API to demo that I can do that.
- Here is a network guide: https://beej.us/guide/bgnet/html//index.html
- Maybe I should read [Programming in Lua, 4th Edition](https://www.goodreads.com/book/show/55647909-programming-in-lua-fourth-edition-by-roberto-ierusalimschy-lua-org?ref=nav_sb_ss_2_18)
- Apparently, http://lua.sqlite.org/index.cgi/home is a thing.
- https://redbean.dev/ is in the same space. Lots of interesting ideas here like TLS, gzip, SQLite


## Unknowns

- What should I do for unit testing C code?
- Should I add an acceptance test?
- How could I integrate valgrind and other C quality checks? I know nothing here.
