#include <dirent.h>
#include <lauxlib.h>
#include <lua.h>
#include <string.h>

// scandir function - returns table of {name, type} entries
static int nibiru_scandir(lua_State *L) {
    const char *path = luaL_checkstring(L, 1);

    DIR *dir = opendir(path);
    if (!dir) {
        lua_pushnil(L);
        lua_pushstring(L, "Failed to open directory");
        return 2;
    }

    lua_newtable(L); // Result table
    int index = 1;

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        // Skip . and ..
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        lua_newtable(L); // Entry table

        // name field
        lua_pushstring(L, "name");
        lua_pushstring(L, entry->d_name);
        lua_settable(L, -3);

        // type field (file or directory)
        lua_pushstring(L, "type");
        if (entry->d_type == DT_DIR) {
            lua_pushstring(L, "directory");
        } else if (entry->d_type == DT_REG) {
            lua_pushstring(L, "file");
        } else {
            lua_pushstring(L, "other");
        }
        lua_settable(L, -3);

        // Add to result table
        lua_rawseti(L, -2, index);
        index++;
    }

    closedir(dir);
    return 1;
}

// Library function table
static const luaL_Reg nibiru_functions[] = {{"scandir", nibiru_scandir},
                                            {NULL, NULL}};

// Library open function
int luaopen_nibiru_core(lua_State *L) {
    luaL_newlib(L, nibiru_functions);
    return 1;
}