#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "crpat/crpat.h"

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <locale.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if LUA_VERSION_NUM < 520
#define lua_rawlen lua_objlen
#endif

#ifndef HAVE_GETTEXT
#define ngettext(msgid1, msgid2, n) ((n==1) ? (msgid1) : (msgid2))
#define gettext(msgid) (msgid)
#endif

typedef struct parser_s {
    lua_State *L;
    char * error;
    CR_Parser parser;
    int stack_depth; /* number of tables on the stack */
    bool subsection; /* current element is a subsection of the object */
} parser_t;

static int block_info(const char *block, int keyc, bool *seq) {
    *seq = (keyc > 0);
    if (strcmp(block, "VERSION") == 0) {
        *seq = 0;
        return 0;
    }
    else if (strcmp(block, "REGION") == 0) {
        return 0;
    }
    else if (strcmp(block, "MESSAGETYPE") == 0) {
        return 0;
    }
    else if (strcmp(block, "TRANSLATION") == 0) {
        return 0;
    }
    else if (strcmp(block, "PARTEI") == 0) {
        return 0;
    }
    else if (strcmp(block, "EINHEIT") == 0) {
        return 1;
    }
    else if (strcmp(block, "SCHIFF") == 0) {
        return 1;
    }
    else if (strcmp(block, "BURG") == 0) {
        return 1;
    }
    return -1;
}

static void new_block(lua_State *L, const char *name) {
    /* stack: parent -> object */
    lua_pushstring(L, name);
    lua_pushvalue(L, -2);
    /* stack: parent -> object -> name -> objref */
    lua_settable(L, -4); /* parent.name = obj */
}

static void new_sequence(lua_State *L, const char *name) {
    /* stack: parent -> object */
    int index = 0;
    lua_pushstring(L, name);
    lua_gettable(L, -3);
    if (lua_isnil(L, -1)) {
        /* the sequence does not exist yet, create it */
        /* remove the failed get result */
        lua_pop(L, 1);
        lua_newtable(L);
        lua_pushstring(L, name);
        lua_pushvalue(L, -2);
        /* stack: parent -> object -> sequence -> name -> seqref */
        lua_settable(L, -5);
        /* stack: parent -> object -> sequence */
        index = 1;
    }
    else {
        /* the sequence exist already, how long is it? */
        size_t len = lua_rawlen(L, -1);
        assert(len < INT_MAX);
        index = (int)len + 1;
    }
    if (index > 0) {
        /* the sequence is now on top of the stack */
        lua_pushvalue(L, -2);
        /* stack: parent -> object -> sequence -> objref */
        /* add the new object to the sequence */
        lua_rawseti(L, -2, index); /* parent.name[index] = obj */
    }
    /* remove sequence, so object is top-of-stack */
    lua_pop(L, 1);
}

static void handle_element(void *udata, const char *name, unsigned int keyc, int keyv[])
{
    parser_t *state = (parser_t *)udata;
    lua_State *L = state->L;
    bool sequence;
    int depth;

    depth = block_info(name, keyc, &sequence);

    /* new table, fix the stack so the parent is on top */
    if (depth >= 0) {
        /* new stack_depth is the number of tables on the stack */
        if (state->stack_depth > depth) {
            /* if there are descendants of our parent on stack, pop them */
            int diff = state->stack_depth - depth;
            lua_pop(L, diff);
            state->stack_depth -= diff;
        }
        state->subsection = false;
    }
    else {
        if (state->subsection) {
            /* pop the current subsection off the stack */
            lua_pop(L, 1);
            --state->stack_depth;
        }
        state->subsection = true;
    }

    /* the parent game object is now on top of the stack */
    lua_newtable(L);
    ++state->stack_depth;
    /* top of stack is the new object */
    if (sequence) {
        /* there can be more than one of this block in the object, we need a sequence */
        new_sequence(L, name);
    }
    else {
        /* this block is not in a sequence */
        new_block(L, name);
    }
    if (keyc > 0) {
        int i;
        /* add keys to a new array: */
        lua_pushstring(L, "keys");
        lua_newtable(L);
        for (i = 0; i != (int)keyc; ++i) {
            lua_pushinteger(L, keyv[i]);
            lua_rawseti(L, -2, i + 1);
        }
        /* add the keys table to our new object: */
        lua_settable(L, -3);
    }
}

static void handle_string(void *udata, const char *name, const char *value) {
    parser_t *state = (parser_t *)udata;
    lua_State *L = state->L;

    assert(lua_istable(L, -1));
    lua_pushstring(L, name);
    lua_pushstring(L, value);
    lua_settable(L, -3);
}

static void handle_number(void *udata, const char *name, long value) {
    parser_t *state = (parser_t *)udata;
    lua_State *L = state->L;

    assert(lua_istable(L, -1));
    lua_pushstring(L, name);
    lua_pushinteger(L, (lua_Integer)value);
    lua_settable(L, -3);
}

static void handle_text(void *udata, const char *text) {
    size_t len;
    int index;
    parser_t *state = (parser_t *)udata;
    lua_State *L = state->L;
    lua_pushstring(L, text);
    len = lua_rawlen(L, -2);
    assert(len < INT_MAX);
    index = (int)len;
    lua_rawseti(L, -2, index + 1);
}

static int parse_crfile(lua_State *L, FILE *in) {
    CR_Parser cp;
    int done = 0;
    char buf[2048], *input;
    parser_t state;
    size_t len;
    const char * filename = lua_tostring(L, 1);

    cp = CR_ParserCreate();
    CR_SetElementHandler(cp, handle_element);
    CR_SetPropertyHandler(cp, handle_string);
    CR_SetNumberHandler(cp, handle_number);
    CR_SetTextHandler(cp, handle_text);

    memset(&state, 0, sizeof(state));
    state.L = L;
    state.parser = cp;
    CR_SetUserData(cp, (void *)&state);

    input = buf;
    len = fread(buf, 1, sizeof(buf), in);
    if (len >= 3 && buf[0] != 'V') {
        /* skip BOM */
        input += 3;
        len -= 3;
    }
    /* first, create the object we want to return */
    lua_newtable(L);
    while (!done) {
        if (ferror(in)) {
            int err = errno;
            errno = 0;
            lua_pop(L, state.stack_depth + 1);
            return luaL_error(L, gettext("read error at line %d of %s: %s\n"),
                CR_GetCurrentLineNumber(cp), filename, strerror(err));
        }
        done = feof(in);
        if (CR_Parse(cp, input, len, done) == CR_STATUS_ERROR) {
            lua_pop(L, state.stack_depth + 1);
            return luaL_error(L, gettext("parse error at line %d of %s: %s\n"),
                CR_GetCurrentLineNumber(cp), filename, 
                CR_ErrorString(CR_GetErrorCode(cp)));
        }
        len = fread(buf, 1, sizeof(buf), in);
        input = buf;
    }
    CR_ParserFree(cp);
    lua_pop(L, state.stack_depth);
    return 1;
}

static int l_crparse(lua_State *L) {
    const char * filename;
    FILE *in;

    if (!lua_isstring(L, 1)) {
        return luaL_error(L, gettext("%s: argument should be a string"), __FUNCTION__);
    }
    filename = lua_tostring(L, 1);
    in = fopen(filename, "rt+");
    if (!in) {
        int error = errno;
        errno = 0;
        lua_pushnil(L);
        lua_pushstring(L, strerror(error));
        return 2;
    }
    return parse_crfile(L, in);
}

static int usage(const char *name) {
    fprintf(stderr, gettext("Usage: %s <script> [arg1 ...]\n"), name);
    return EXIT_FAILURE;
}

int main (int argc, char *argv[]) {
    lua_State *L = luaL_newstate();
    int i;
    const char * script = NULL;

    if (argc < 1) {
        return usage(argv[0]);
    }
    script = argv[1];

    luaL_openlibs(L);
    setlocale(LC_ALL, "");

    lua_newtable(L);
    for (i = 1; i != argc; ++i) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i - 1);
    }
    lua_setglobal(L, "arg");
    lua_pushcfunction(L, l_crparse);
    lua_setglobal(L, "crparse");

    if (luaL_dofile(L, script)) {
        fprintf(stderr, "%s: %s\n", script, lua_tostring(L, -1));
    }
    lua_close(L);
    return EXIT_SUCCESS;
}

