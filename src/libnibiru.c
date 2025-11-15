#include <lauxlib.h>
#include <lua.h>

// Dummy function for testing library loading
static int nibiru_dummy(lua_State *L) {
    lua_pushstring(L, "Hello from libnibiru!");
    return 1;
}

// Library function table
static const luaL_Reg nibiru_functions[] = {{"dummy", nibiru_dummy},
                                            {NULL, NULL}};

// Library open function
int luaopen_nibiru(lua_State *L) {
    luaL_newlib(L, nibiru_functions);
    return 1;
}