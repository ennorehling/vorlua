#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdio.h>
#include <stdlib.h>

int main (int argc, char *argv[]) {
    lua_State *L = lua_open();
    luaL_openlibs(L);



    lua_close(L);
    return 0;
}
