#include "crpat/crpat.h"

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void handle_element(void *udata, const char *name,
        const char **attr)
{
    lua_State *L = (lua_State *)udata;
    
    if (strcmp("EINHEIT", name) == 0) {
        
    }
}

static int parse_crfile(const char *filename) {
    CR_Parser cp;
    int done = 0, err = 0;
    char buf[2048];
    FILE * in = fopen(filename, "rt+");

    if (!in) {
        fprintf(stderr,
                "could not open %s: %s\n",
                filename, strerror(errno));
        return errno;
    }
    cp = CR_ParserCreate();
    CR_SetElementHandler(cp, handle_element);
    CR_SetPropertyHandler(cp, handle_property);
    CR_SetTextHandler(cp, handle_text);
    CR_SetUserData(cp, (void *)L);

    while (!done) {
        size_t len = (int)fread(buf, 1, sizeof(buf), in);
        if (ferror(in)) {
            fprintf(stderr, 
                    "read error at line %d of %s: %s\n",
                    CR_GetCurrentLineNumber(cp),
                    filename, strerror(errno));
            err = errno;
            break;
        }
        done = feof(in);
        if (CR_Parse(cp, buf, len, done) == CR_STATUS_ERROR) {
            fprintf(stderr,
                    "parse error at line %d of %s: %s\n",
                    CR_GetCurrentLineNumber(cp),
                    filename, CR_ErrorString(CR_GetErrorCode(cp)));
            err = -1;
            break;
        }
    }
    CR_ParserFree(cp);
    return err;
}

int main (int argc, char *argv[]) {
    lua_State *L = lua_open();
    luaL_openlibs(L);

    parse_crfile("example/sample.cr");

    lua_close(L);
    return 0;
}

