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
    type = "make",
    makefile = "Makefile.luarocks",

    build_target = "all",

    build_variables = {
        CFLAGS = "$(CFLAGS)",
    },

    modules = {
        ["nibiru_core"] = "lua/nibiru_core.so",
    },
    install = {
        bin = {
            nibiru = "nibiru",
        },
    },
    copy_directories = { "lua/nibiru", "docs" },
}
