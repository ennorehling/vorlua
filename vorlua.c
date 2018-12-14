#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "crpat/crpat.h"

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef HAVE_GETTEXT
#define ngettext(msgid1, msgid2, n) ((n==1) ? (msgid1) : (msgid2))
#define gettext(msgid) (msgid)
#endif

typedef struct parser_s {
    lua_State *L;
    enum block_e {
        BLOCK_NONE,
        BLOCK_REPORT,
        BLOCK_FACTION,
        BLOCK_REGION,
        BLOCK_UNIT,
        BLOCK_SHIP,
        BLOCK_BUILDING,
        BLOCK_UNKNOWN,
    } block;
    char * error;
    CR_Parser parser;
    int num_factions;
    int num_regions;
    int num_units;
    int num_ships;
    int num_buildings;
    int num_strings;
    int stack_depth;
} parser_t;

static void error(parser_t *state, const char *format, ...) {
    va_list ap;
    int size;

    va_start(ap, format);
    size = vsnprintf(NULL, 0, format, ap);
    state->error = malloc(size + 1);
    if (state->error) {
        vsnprintf(state->error, size + 1, format, ap);
    }
    CR_StopParser(state->parser);
}

static void warn(parser_t *state, const char *format, ...) {
    va_list ap;
    int size;

    va_start(ap, format);
    size = vsnprintf(NULL, 0, format, ap);
    state->error = malloc(size + 1);
    if (state->error) {
        vsnprintf(state->error, size + 1, format, ap);
    }
    CR_StopParser(state->parser);
}

static int stack_depth(enum block_e block) {
    switch (block) {
    case BLOCK_NONE:
        return 0;
    case BLOCK_REPORT:
        return 1;
    case BLOCK_REGION:
    case BLOCK_FACTION:
        return 2;
    case BLOCK_UNIT:
    case BLOCK_SHIP:
    case BLOCK_BUILDING:
        return 3;
    }
    return -1;
}

static int state_update(parser_t *state, enum block_e parent, enum block_e child)
{
    lua_State *L = state->L;
    int depth = state->stack_depth;
    if (depth >= 0) {
        int target = stack_depth(parent);
        if (target >= 0) {
            int change = depth - target;
            if (change >= 0) {
                lua_pop(L, change);
                state->block = child;
                state->stack_depth = stack_depth(child);
                return change;
            }
        }
    }
    error(state, "state_update(%d, %d) failed at depth %d", (int)parent, (int)child, state->stack_depth);
    return -1;
}


static void handle_element(void *udata, const char *name,
        const char **attr)
{
    parser_t *state = (parser_t *)udata;
    lua_State *L = state->L;
    
    if (state->block == BLOCK_NONE) {
        if (strcmp("VERSION", name) == 0) {
            int version;
            if (attr[0] == NULL) {
                error(state, gettext("%s expects %d argument"), name, 1);
                return;
            }
            version = atoi(attr[0]);
            if (version < 66) {
                error(state, gettext("unknown report version %d"), version);
                return;
            }
            state_update(state, BLOCK_NONE, BLOCK_REPORT);
            state->num_factions = 0;
            state->num_regions = 0;
            lua_newtable(L);
            lua_pushstring(L, "version");
            lua_pushinteger(L, version);
            lua_rawset(L, -3);
        }
        else {
            warn(state, gettext("unknown block %s"), name);
            state->block = BLOCK_UNKNOWN;
        }
    }
    else {
        if (strcmp("EINHEIT", name) == 0) {
            int no;

            state_update(state, BLOCK_REGION, BLOCK_UNIT);
            if (attr[0] == NULL) {
                error(state, gettext("%s expects %d argument"), name, 1);
                return;
            }
            no = atoi(attr[0]);
            lua_pushstring(L, "units");
            lua_gettable(L, -2);
            if (!lua_istable(L, -1)) {
                assert(state->num_units == 0);
                lua_newtable(L);
                lua_pushstring(L, "units");
                lua_pushvalue(L, -2);
                lua_rawset(L, -3);
            }
            lua_newtable(L);
            lua_pushvalue(L, -1);
            lua_pushstring(L, "id");
            lua_pushinteger(L, no);
            lua_rawset(L, -3);
            lua_rawseti(L, -2, ++state->num_units);
        }
        else if (strcmp("SCHIFF", name) == 0) {
            int no;

            state_update(state, BLOCK_REGION, BLOCK_SHIP);
            if (attr[0] == NULL) {
                error(state, gettext("%s expects %d argument"), name, 1);
                return;
            }
            no = atoi(attr[0]);
            lua_pushstring(L, "ships");
            lua_gettable(L, -2);
            if (!lua_istable(L, -1)) {
                assert(state->num_ships == 0);
                lua_newtable(L);
                lua_pushstring(L, "ships");
                lua_pushvalue(L, -2);
                lua_rawset(L, -3);
            }
            lua_newtable(L);
            lua_pushvalue(L, -1);
            lua_pushstring(L, "id");
            lua_pushinteger(L, no);
            lua_rawset(L, -3);
            lua_rawseti(L, -2, ++state->num_ships);
        }
        else if (strcmp("BURG", name) == 0) {
            int no;

            state_update(state, BLOCK_REGION, BLOCK_BUILDING);
            if (attr[0] == NULL) {
                error(state, gettext("%s expects %d argument"), name, 1);
                return;
            }
            no = atoi(attr[0]);
            lua_pushstring(L, "buildings");
            lua_gettable(L, -2);
            if (!lua_istable(L, -1)) {
                assert(state->num_buildings == 0);
                lua_newtable(L);
                lua_pushstring(L, "buildings");
                lua_pushvalue(L, -2);
                lua_rawset(L, -3);
            }
            lua_newtable(L);
            lua_pushvalue(L, -1);
            lua_pushstring(L, "id");
            lua_pushinteger(L, no);
            lua_rawset(L, -3);
            lua_rawseti(L, -2, ++state->num_ships);
        }
        else if (strcmp("PARTEI", name) == 0) {
            int no;

            state_update(state, BLOCK_REPORT, BLOCK_FACTION);
            if (attr[0] == NULL) {
                error(state, gettext("%s expects %d argument"), name, 1);
                return;
            }
            no = atoi(attr[0]);
            lua_pushstring(L, "factions");
            lua_gettable(L, -2);
            if (!lua_istable(L, -1)) {
                assert(state->num_factions == 0);
                lua_newtable(L);
                lua_pushstring(L, "factions");
                lua_pushvalue(L, -2);
                lua_rawset(L, -3);
            }
            lua_newtable(L);
            lua_pushvalue(L, -1);
            lua_pushstring(L, "id");
            lua_pushinteger(L, no);
            lua_rawset(L, -3);
            lua_rawseti(L, -2, ++state->num_factions);
        }
        else if (strcmp("REGION", name) == 0) {
            int x, y, z = 0;

            if (attr[0] == NULL || attr[1] == NULL) {
                error(state, gettext("%s expects %d or more arguments"), name, 2);
                return;
            }
            x = atoi(attr[0]);
            y = atoi(attr[1]);
            if (attr[2]) {
                z = atoi(attr[2]);
            }
            state_update(state, BLOCK_REPORT, BLOCK_REGION);
            lua_pushstring(L, "regions");
            lua_gettable(L, -2);
            if (!lua_istable(L, -1)) {
                lua_pushstring(L, "regions");
                lua_newtable(L);
                lua_pushvalue(L, -1);
                lua_rawset(L, -3);
            }
            state->num_units = 0;
            lua_newtable(L);
            lua_pushvalue(L, -1);
            lua_pushstring(L, "x");
            lua_pushinteger(L, x);
            lua_rawset(L, -3);
            lua_pushstring(L, "y");
            lua_pushinteger(L, y);
            lua_rawset(L, -3);
            if (z != 0) {
                lua_pushstring(L, "z");
                lua_pushinteger(L, z);
                lua_rawset(L, -3);
            }
            lua_rawseti(L, -2, ++state->num_regions);
        }
        else {
            warn(state, gettext("unknown block %s"), name);
            state->block = BLOCK_UNKNOWN;
        }
    }
}

static void handle_property(void *udata, const char *name, const char *value) {
    parser_t *state = (parser_t *)udata;
    lua_State *L = state->L;

    if (state->block != BLOCK_UNKNOWN) {
        lua_pushstring(L, name);
        lua_pushstring(L, value);
        lua_rawset(L, -3);
    }
}

static void handle_text(void *udata, const char *text) {
}

static int parse_crfile(lua_State *L, const char *filename) {
    CR_Parser cp;
    int done = 0, err = 0;
    char buf[2048], *input;
    FILE * in = fopen(filename, "rt+");
    parser_t state;
    size_t len;

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

    state.L = L;
    state.block = BLOCK_NONE;
    state.error = NULL;
    state.parser = cp;
    state.stack_depth = 0;
    CR_SetUserData(cp, (void *)&state);

    input = buf;
    len = fread(buf, 1, sizeof(buf), in);
    if (len >= 3 && buf[0] != 'V') {
        /* skip BOM */
        input += 3;
        len -= 3;
    }
    while (!done) {
        if (ferror(in)) {
            fprintf(stderr, 
                    "read error at line %d of %s: %s\n",
                    CR_GetCurrentLineNumber(cp),
                    filename, strerror(errno));
            err = errno;
            break;
        }
        done = feof(in);
        if (CR_Parse(cp, input, len, done) == CR_STATUS_ERROR) {
            fprintf(stderr,
                    "parse error at line %d of %s: %s\n",
                    CR_GetCurrentLineNumber(cp),
                    filename, CR_ErrorString(CR_GetErrorCode(cp)));
            err = -1;
            break;
        }
        len = fread(buf, 1, sizeof(buf), in);
        input = buf;
    }
    CR_ParserFree(cp);
    return err;
}

int main (int argc, char *argv[]) {
    lua_State *L = lua_open();
    luaL_openlibs(L);

    parse_crfile(L, "crpat/example/sample.cr");

    lua_close(L);
    return 0;
}

