#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>

int main(void) {
    lua_State *lua_state = luaL_newstate();
    luaL_openlibs(lua_state);

    // Load the module.
    lua_getglobal(lua_state, "require");
    const char* module_name = "nibiru_package_test.connection";
    lua_pushstring(lua_state, module_name);
    int status = lua_pcall(lua_state, 1, 1, 0);
    if (status != LUA_OK) {
        printf("Error: %s\n", lua_tostring(lua_state, -1));
        lua_close(lua_state);
        return 1;
    }

    int lua_type = lua_getfield(lua_state, -1, "handle_connection");
    if (lua_type != LUA_TFUNCTION) {
        printf("Unexpected type: handle_connection is not a function.");
        lua_close(lua_state);
        return 1;
    }

    int handle_connection_reference = luaL_ref(lua_state, LUA_REGISTRYINDEX);

    // Take the module off the stack to clean up.
    lua_pop(lua_state, 1);

    // Add handle_connection back to the stack.
    lua_rawgeti(lua_state, LUA_REGISTRYINDEX, handle_connection_reference);

    const char* data = "Hello from C!";
    lua_pushstring(lua_state, data);

    status = lua_pcall(lua_state, 1, 1, 0);
    if (status != LUA_OK) {
        printf("Error: %s\n", lua_tostring(lua_state, -1));
        lua_close(lua_state);
        return 1;
    }

    const char* response = lua_tostring(lua_state, -1);

    printf("%s\n", response);

    // Only pop after C has the chance to do something. If I don't,
    // then there is a chance that the Lua GC kicks in and frees the memory.
    // That's silly for this example, but could matter in a real setting.
    lua_pop(lua_state, 1);

    lua_close(lua_state);

    printf("ok\n");

    return 0;
}
