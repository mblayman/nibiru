#include <lua.h>
#include <lauxlib.h>

int main(void) {
    lua_State *lua_state = luaL_newstate();

    lua_close(lua_state);
    return 0;
}
