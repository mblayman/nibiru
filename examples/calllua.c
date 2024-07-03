#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>

int main(void) {
    lua_State *lua_state = luaL_newstate();
    luaL_openlibs(lua_state);

    const char* lua_script = "connection.lua";
    int status = luaL_loadfile(lua_state, lua_script);
    if (status != LUA_OK) {
        printf("Error: %s\n", lua_tostring(lua_state, -1));
        return 1;
    }

    lua_close(lua_state);

    printf("ok\n");

    return 0;
}
