#include <dirent.h>
#include <lauxlib.h>
#include <limits.h>
#include <lua.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// Dynamic array to collect file paths
typedef struct {
    char **paths;
    size_t count;
    size_t capacity;
} FileList;

// Initialize file list
static void file_list_init(FileList *list) {
    list->paths = NULL;
    list->count = 0;
    list->capacity = 0;
}

// Add path to file list
static void file_list_add(FileList *list, const char *path) {
    if (list->count >= list->capacity) {
        list->capacity = list->capacity == 0 ? 16 : list->capacity * 2;
        list->paths = realloc(list->paths, list->capacity * sizeof(char *));
    }
    list->paths[list->count] = strdup(path);
    list->count++;
}

// Free file list
static void file_list_free(FileList *list) {
    for (size_t i = 0; i < list->count; i++) {
        free(list->paths[i]);
    }
    free(list->paths);
    list->paths = NULL;
    list->count = 0;
    list->capacity = 0;
}

// Comparison function for qsort
static int compare_paths(const void *a, const void *b) {
    return strcmp(*(const char **)a, *(const char **)b);
}

// Helper function to collect files recursively
static void collect_files_recursive(const char *base_path,
                                    const char *relative_path, FileList *list) {
    char full_path[PATH_MAX];
    if (relative_path[0] == '\0') {
        strcpy(full_path, base_path);
    } else {
        snprintf(full_path, PATH_MAX, "%s/%s", base_path, relative_path);
    }

    DIR *dir = opendir(full_path);
    if (!dir) {
        return; // Skip inaccessible directories
    }

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        // Skip . and ..
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        char child_relative[PATH_MAX];
        if (relative_path[0] == '\0') {
            strcpy(child_relative, entry->d_name);
        } else {
            snprintf(child_relative, PATH_MAX, "%s/%s", relative_path,
                     entry->d_name);
        }

        char child_full[PATH_MAX];
        snprintf(child_full, PATH_MAX, "%s/%s", base_path, child_relative);

        struct stat st;
        if (stat(child_full, &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                // Recurse into directory
                collect_files_recursive(base_path, child_relative, list);
            } else if (S_ISREG(st.st_mode)) {
                // Add file to list
                file_list_add(list, child_relative);
            }
        }
    }

    closedir(dir);
}

// files_from function - returns sorted array of relative file paths (recursive)
static int nibiru_files_from(lua_State *L) {
    const char *path = luaL_checkstring(L, 1);

    // Check if path exists and is a directory
    struct stat st;
    if (stat(path, &st) != 0 || !S_ISDIR(st.st_mode)) {
        lua_pushnil(L);
        lua_pushstring(L, "Path does not exist or is not a directory");
        return 2;
    }

    // Collect all files
    FileList list;
    file_list_init(&list);
    collect_files_recursive(path, "", &list);

    // Sort the file list alphabetically
    if (list.count > 1) {
        qsort(list.paths, list.count, sizeof(char *), compare_paths);
    }

    // Create Lua table with sorted results
    lua_newtable(L);
    for (size_t i = 0; i < list.count; i++) {
        lua_pushstring(L, list.paths[i]);
        lua_rawseti(L, -2, i + 1);
    }

    file_list_free(&list);
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