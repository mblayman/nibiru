#include <dirent.h>
#include <lauxlib.h>
#include <limits.h>
#include <lua.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// Helper function to collect files recursively
static void collect_files_recursive(const char *base_path,
                                    const char *current_path, lua_State *L,
                                    int *index) {
    char full_path[PATH_MAX];
    if (current_path[0] == '\0') {
        strcpy(full_path, base_path);
    } else {
        snprintf(full_path, PATH_MAX, "%s/%s", base_path, current_path);
    }

    DIR *dir = opendir(full_path);
    if (!dir)
        return;

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        // Skip . and ..
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        if (entry->d_type == DT_DIR) {
            // Recurse into subdirectory
            char sub_path[PATH_MAX];
            if (current_path[0] == '\0') {
                strcpy(sub_path, entry->d_name);
            } else {
                snprintf(sub_path, PATH_MAX, "%s/%s", current_path,
                         entry->d_name);
            }
            collect_files_recursive(base_path, sub_path, L, index);
        } else if (entry->d_type == DT_REG) {
            // Add file with relative path
            char relative_path[PATH_MAX];
            if (current_path[0] == '\0') {
                strcpy(relative_path, entry->d_name);
            } else {
                snprintf(relative_path, PATH_MAX, "%s/%s", current_path,
                         entry->d_name);
            }

            lua_pushstring(L, relative_path);
            lua_rawseti(L, -2, *index);
            (*index)++;
        }
    }

    closedir(dir);
}

// files_from function - returns array of relative file paths (recursive)
static int nibiru_files_from(lua_State *L) {
    const char *path = luaL_checkstring(L, 1);

    // Check if path exists and is a directory
    struct stat st;
    if (stat(path, &st) != 0 || !S_ISDIR(st.st_mode)) {
        lua_pushnil(L);
        lua_pushstring(L, "Path does not exist or is not a directory");
        return 2;
    }

    DIR *dir = opendir(path);
    if (!dir) {
        lua_pushnil(L);
        lua_pushstring(L, "Failed to open directory");
        return 2;
    }

    lua_newtable(L); // Result table
    int index = 1;

    collect_files_recursive(path, "", L, &index);

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