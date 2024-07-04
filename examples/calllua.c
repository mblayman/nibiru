#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>

int main(void) {
    lua_State *lua_state = luaL_newstate();
    luaL_openlibs(lua_state);

    // Load and compile the script.
    const char* lua_script = "connection.lua";
    int status = luaL_loadfile(lua_state, lua_script);
    if (status != LUA_OK) {
        printf("Error: %s\n", lua_tostring(lua_state, -1));
        return 1;
    }

    // Create the module and add to the top of the Lua stack.
    status = lua_pcall(lua_state, 0, 1, 0);
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
    // XXX: take the module of the stack. is this necessary?
    lua_pop(lua_state, 1);

    // Add handle_connection back to the stack.
    lua_rawgeti(lua_state, LUA_REGISTRYINDEX, handle_connection_reference);

    status = lua_pcall(lua_state, 0, 0, 0);
    if (status != LUA_OK) {
        printf("Error: %s\n", lua_tostring(lua_state, -1));
        lua_close(lua_state);
        return 1;
    }

    lua_close(lua_state);

    printf("ok\n");

    return 0;
}
