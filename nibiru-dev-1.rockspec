rockspec_format = "3.0"
package = "nibiru"
version = "dev-1"

source = { url = "git+https://github.com/mblayman/nibiru.git" }

description = {
    summary = "A Lua web framework",
    detailed = "A way out there idea deserves a way out there name",
    homepage = "https://github.com/mblayman/nibiru",
    license = "MIT",
}

dependencies = { "lua >= 5.1" }

build = {
    type = "command",

    build_command = [[
        # Build C library
        mkdir -p lua
        $(CC) $(CFLAGS) -fPIC -shared -o lua/nibiru_core.so src/libnibiru.c $(LIBFLAG)

        # Build binary as executable (not shared library) - don't use LIBFLAG
        $(CC) $(CFLAGS) -o nibiru src/main.c src/parse.c -llua
    ]],

    install_command = [[
        # Install C library
        mkdir -p $(LIBDIR)
        cp lua/nibiru_core.so $(LIBDIR)/nibiru_core.so

        # Install binary
        mkdir -p $(BINDIR)
        cp nibiru $(BINDIR)/nibiru

        # Install Lua modules
        mkdir -p $(LUADIR)/nibiru
        cp -r lua/nibiru/* $(LUADIR)/nibiru/

        # Install docs
        mkdir -p $(DOCDIR)
        cp -r docs/* $(DOCDIR)/ 2>/dev/null || true
    ]],

    copy_directories = { "docs" },
}
