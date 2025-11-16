#include <dirent.h>
#include <lauxlib.h>
#include <lua.h>
#include <string.h>

// files_from function - returns array of filenames (files only)
static int nibiru_files_from(lua_State *L) {
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
        // Skip . and .. and directories
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0 || entry->d_type == DT_DIR) {
            continue;
        }

        // Only include regular files
        if (entry->d_type == DT_REG) {
            lua_pushstring(L, entry->d_name);
            lua_rawseti(L, -2, index);
            index++;
        }
    }

    closedir(dir);
    return 1;
}

// Library function table
static const luaL_Reg nibiru_functions[] = {{"files_from", nibiru_files_from},
                                            {NULL, NULL}};

// Library open function
int luaopen_nibiru_core(lua_State *L) {
    luaL_newlib(L, nibiru_functions);
    return 1;
}