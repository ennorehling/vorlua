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

#ifndef HAVE_GETTEXT
#define ngettext(msgid1, msgid2, n) ((n==1) ? (msgid1) : (msgid2))
#define gettext(msgid) (msgid)
#endif

typedef struct parser_s {
    lua_State *L;
    char * error;
    CR_Parser parser;
    int stack_depth;
    bool child;
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
    va_end(ap);
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
    va_end(ap);
    CR_StopParser(state->parser);
}

static int block_info(const char *block, int keyc, int *multi) {
    *multi = (keyc > 0);
    if (strcmp(block, "VERSION") == 0) {
        *multi = 0;
        return 0;
    }
    else if (strcmp(block, "REGION") == 0) {
        return 0;
    }
    else if (strcmp(block, "MESSAGETYPE") == 0) {
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

static void handle_element(void *udata, const char *name, unsigned int keyc, int keyv[])
{
    parser_t *state = (parser_t *)udata;
    lua_State *L = state->L;
    int depth, multi;
    
    depth = block_info(name, keyc, &multi);

    if (state->child) {
        /* if the last element was the child of a game object, pop it off the stack */
        lua_pop(L, 1);
        --state->stack_depth;
    }
    if (depth < 0) {
        /* this element is still part of the current game object */
        state->child = true;
    }
    else {
        /* this is a new game object, fix the stack so the parent is on top */
        int diff = state->stack_depth - depth;
        assert(diff >= 0);
        lua_pop(L, diff);
        state->stack_depth = depth;
        state->child = false;

        /* game objects need key atttributes */
        if (keyc == 0) {
            error(state, gettext("%s expects at least one key argument"), name);
            return;
        }
    }
    /* the parent game object is on top of the stack */
    if (keyc > 0) {
        int index = 0, i;

        /* create the new object */
        lua_newtable(L);
        if (multi) {
            /* there can be more than one of this block in the object, we need a sequence */
            lua_pushstring(L, name);
            lua_gettable(L, -3);
            if (lua_istable(L, -1)) {
                size_t len = lua_objlen(L, -1);
                assert(len < INT_MAX);
                index = (int)len + 1;
            }
            else {
                /* remove the failed get result */
                lua_pop(L, 1);
                /* list does not exist yet, add it */
                lua_newtable(L);
                lua_pushstring(L, name);
                lua_pushvalue(L, -2);
                lua_settable(L, -5);
                index = 1;
            }
        }
        if (index > 0) {
            /* the sequence is now on top of the stack */
            lua_pushvalue(L, -2);
            /* copy of the new object is on top of the stack */
            lua_rawseti(L, -2, index);
            /* new object has been appended, remove sequence: */
            lua_pop(L, 1);
        }
        else {
            /* this block is not in a sequence */
            lua_pushstring(L, name);
            lua_pushvalue(L, -2);
            lua_settable(L, -4);
        }
        /* new object is on top of stack */

        /* add keys to a new array: */
        lua_pushstring(L, "keys");
        lua_newtable(L);
        for (i = 0; i != (int)keyc; ++i) {
            lua_pushinteger(L, keyv[i]);
            lua_rawseti(L, -2, i + 1);
        }
        /* add the keys to the new object: */
        lua_settable(L, -3);
    }
    else {
        lua_newtable(L);
        lua_pushstring(L, name);
        lua_pushvalue(L, -2);
        lua_settable(L, -4);
    }
    /* the new object is on top of the stack */
    ++state->stack_depth;
}

static void handle_string(void *udata, const char *name, const char *value) {
    parser_t *state = (parser_t *)udata;
    lua_State *L = state->L;

    assert(lua_istable(L, -1));
    lua_pushstring(L, name);
    lua_pushstring(L, value);
    lua_settable(L, -3);
}

static void handle_number(void *udata, const char *name, double value) {
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
    len = lua_objlen(L, -2);
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

static void l_abort(lua_State *L, const char *fmt, ...) {
    va_list argp;
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    va_end(argp);
    lua_close(L);
    exit(EXIT_FAILURE);
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
    lua_State *L = lua_open();
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
        fputs(lua_tostring(L, -1), stderr);
    }
    lua_close(L);
    return EXIT_SUCCESS;
}

