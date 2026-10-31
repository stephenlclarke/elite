#include "MissionScript.h"
#include <CLua.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* luaL_error reaches luaD_throw through lua_error; its public int return is unreachable. */
extern int luaL_error(lua_State *L, const char *fmt, ...) __attribute__((noreturn));

#define EMS_DEPTH 32
#define EMS_ITEMS 16384
#define EMS_HOOK 1000

typedef struct {
  const unsigned char *source, *input;
  size_t source_count, input_count, cursor;
  const char *handler;
  EMSLimits limits;
  EMSResult result;
  size_t heap, allocated, output_capacity;
  uint64_t instructions;
  const void *ancestors[EMS_DEPTH];
  unsigned items;
} EMSContext;

static void *allocate(void *ud, void *ptr, size_t old_size, size_t new_size) {
  EMSContext *ctx = ud;
  if (!ptr) old_size = 0; /* Lua uses a type tag for new allocations. */
  if (!new_size) {
    ctx->heap -= old_size;
    free(ptr);
    return NULL;
  }
  size_t growth = new_size > old_size ? new_size - old_size : 0;
  if (growth > ctx->limits.heap_bytes - ctx->heap ||
      new_size > ctx->limits.allocation_bytes - ctx->allocated) return NULL;
  void *next = realloc(ptr, new_size);
  if (next) {
    ctx->heap = ctx->heap - old_size + new_size;
    ctx->allocated += new_size;
    if (ctx->heap > ctx->result.peak_heap_bytes) ctx->result.peak_heap_bytes = ctx->heap;
  }
  return next;
}

static EMSContext *context(lua_State *L) {
  void *ud = NULL;
  lua_getallocf(L, &ud);
  return ud;
}

static void instruction_hook(lua_State *L, lua_Debug *ar) {
  (void)ar;
  EMSContext *ctx = context(L);
  ctx->instructions += EMS_HOOK;
  if (ctx->instructions >= ctx->limits.instructions) luaL_error(L, "Instruction budget exceeded.");
}

static void read_bytes(lua_State *L, void *out, size_t count) {
  EMSContext *ctx = context(L);
  if (count > ctx->input_count - ctx->cursor) luaL_error(L, "Truncated input.");
  memcpy(out, ctx->input + ctx->cursor, count);
  ctx->cursor += count;
}

static uint32_t read_length(lua_State *L) {
  unsigned char b[4];
  read_bytes(L, b, 4);
  return (uint32_t)b[0] | ((uint32_t)b[1] << 8) | ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

static void read_string(lua_State *L) {
  EMSContext *ctx = context(L);
  uint32_t count = read_length(L);
  if (count > ctx->input_count - ctx->cursor) luaL_error(L, "Invalid string length.");
  lua_pushlstring(L, (const char *)ctx->input + ctx->cursor, count);
  ctx->cursor += count;
}

/* The wire format preserves signed 64-bit integers and bounded value trees. */
static void read_value(lua_State *L, unsigned depth) {
  EMSContext *ctx = context(L);
  if (depth >= EMS_DEPTH || ++ctx->items > EMS_ITEMS) luaL_error(L, "Input nesting/items exceeded.");
  luaL_checkstack(L, 4, "Input nesting exceeded.");
  unsigned char tag;
  read_bytes(L, &tag, 1);
  switch (tag) {
    case 0: lua_pushnil(L); break;
    case 1: lua_pushboolean(L, 0); break;
    case 2: lua_pushboolean(L, 1); break;
    case 3: {
      int64_t value;
      read_bytes(L, &value, sizeof(value));
      lua_pushinteger(L, (lua_Integer)value);
      break;
    }
    case 4: {
      double value;
      read_bytes(L, &value, sizeof(value));
      if (!isfinite(value)) luaL_error(L, "Nonfinite input.");
      lua_pushnumber(L, value);
      break;
    }
    case 5: read_string(L); break;
    case 6: case 7: {
      uint32_t count = read_length(L);
      if (count > EMS_ITEMS) luaL_error(L, "Input collection exceeded.");
      lua_createtable(L, tag == 6 ? (int)count : 0, tag == 7 ? (int)count : 0);
      for (uint32_t i = 0; i < count; ++i) {
        if (tag == 7) read_string(L);
        read_value(L, depth + 1);
        if (tag == 6) lua_rawseti(L, -2, i + 1);
        else lua_rawset(L, -3);
      }
      break;
    }
    default: luaL_error(L, "Invalid input tag.");
  }
}

static void write_bytes(lua_State *L, const void *bytes, size_t count) {
  EMSContext *ctx = context(L);
  if (count > ctx->limits.output_bytes - ctx->result.count) luaL_error(L, "Output budget exceeded.");
  size_t needed = ctx->result.count + count;
  size_t capacity = ctx->output_capacity;
  unsigned char *next = ctx->result.bytes;
  if (needed > capacity) {
    capacity = needed < 4096 ? 4096 : needed * 2;
    if (capacity > ctx->limits.output_bytes) capacity = ctx->limits.output_bytes;
    next = realloc(ctx->result.bytes, capacity);
  }
  if (next) {
    ctx->result.bytes = next;
    ctx->output_capacity = capacity;
    memcpy(next + ctx->result.count, bytes, count);
    ctx->result.count = needed;
  } else {
    luaL_error(L, "Output allocation failed.");
  }
}

static void write_tag(lua_State *L, unsigned char tag) { write_bytes(L, &tag, 1); }
static void write_length(lua_State *L, size_t length) {
  if (length > UINT32_MAX) luaL_error(L, "Value too large.");
  unsigned char bytes[4] = {length & 255, (length >> 8) & 255, (length >> 16) & 255, (length >> 24) & 255};
  write_bytes(L, bytes, 4);
}
static void write_string(lua_State *L, int index) {
  size_t count;
  const char *bytes = lua_tolstring(L, index, &count);
  write_length(L, count);
  write_bytes(L, bytes, count);
}

static void write_value(lua_State *L, int index, unsigned depth) {
  EMSContext *ctx = context(L);
  if (depth >= EMS_DEPTH || ++ctx->items > EMS_ITEMS) luaL_error(L, "Output nesting/items exceeded.");
  luaL_checkstack(L, 4, "Output nesting exceeded.");
  index = lua_absindex(L, index);
  switch (lua_type(L, index)) {
    case LUA_TNIL: write_tag(L, 0); break;
    case LUA_TBOOLEAN: write_tag(L, lua_toboolean(L, index) ? 2 : 1); break;
    case LUA_TNUMBER:
      if (lua_isinteger(L, index)) {
        int64_t value = lua_tointeger(L, index);
        write_tag(L, 3); write_bytes(L, &value, sizeof(value));
      } else {
        double value = lua_tonumber(L, index);
        if (!isfinite(value)) luaL_error(L, "Nonfinite result.");
        write_tag(L, 4); write_bytes(L, &value, sizeof(value));
      }
      break;
    case LUA_TSTRING: write_tag(L, 5); write_string(L, index); break;
    case LUA_TTABLE: {
      const void *identity = lua_topointer(L, index);
      for (unsigned i = 0; i < depth; ++i)
        if (ctx->ancestors[i] == identity) luaL_error(L, "Cyclic result.");
      ctx->ancestors[depth] = identity;
      size_t count = 0, maximum = 0;
      int strings = 0, integers = 0;
      lua_pushnil(L);
      while (lua_next(L, index)) {
        if (++count > EMS_ITEMS) luaL_error(L, "Result collection exceeded.");
        if (lua_type(L, -2) == LUA_TSTRING) strings = 1;
        else if (lua_isinteger(L, -2) && lua_tointeger(L, -2) > 0 && lua_tointeger(L, -2) <= EMS_ITEMS) {
          integers = 1;
          size_t key = (size_t)lua_tointeger(L, -2);
          if (key > maximum) maximum = key;
        } else luaL_error(L, "Result keys must be strings or dense positive indices.");
        lua_pop(L, 1);
      }
      if ((strings && integers) || (integers && maximum != count)) luaL_error(L, "Mixed or sparse result table.");
      write_tag(L, integers ? 6 : 7); /* Empty tables are empty maps. */
      write_length(L, count);
      if (integers) {
        for (size_t i = 1; i <= count; ++i) {
          lua_rawgeti(L, index, (lua_Integer)i);
          write_value(L, -1, depth + 1); lua_pop(L, 1);
        }
      } else {
        lua_pushnil(L);
        while (lua_next(L, index)) {
          write_string(L, -2);
          write_value(L, -1, depth + 1); lua_pop(L, 1);
        }
      }
      ctx->ancestors[depth] = NULL;
      break;
    }
    default: luaL_error(L, "Result contains a nonserializable value.");
  }
}

static int scalar_string(lua_State *L) {
  int type = lua_type(L, 1);
  if (type != LUA_TSTRING && type != LUA_TNUMBER && type != LUA_TBOOLEAN && type != LUA_TNIL)
    luaL_error(L, "tostring accepts scalar values only.");
  luaL_tolstring(L, 1, NULL);
  return 1;
}

static void clear_global(lua_State *L, const char *name) {
  lua_pushnil(L); lua_setglobal(L, name);
}

static int run(lua_State *L) {
  EMSContext *ctx = context(L);
  luaL_requiref(L, "_G", luaopen_base, 1); lua_pop(L, 1);
  /* No loader, I/O, metatables, catch/resume, unordered traversal or RNG. */
  const char *removed[] = {"_G", "collectgarbage", "dofile", "loadfile", "load", "print", "warn",
    "pcall", "xpcall", "getmetatable", "setmetatable", "rawget", "rawset", "rawequal", "pairs", "next", NULL};
  for (int i = 0; removed[i]; ++i) clear_global(L, removed[i]);
  lua_pushcfunction(L, scalar_string); lua_setglobal(L, "tostring");
  luaL_requiref(L, "math", luaopen_math, 1);
  lua_pushnil(L); lua_setfield(L, -2, "random");
  lua_pushnil(L); lua_setfield(L, -2, "randomseed");
  lua_pop(L, 1);
  int status = luaL_loadbufferx(L, (const char *)ctx->source, ctx->source_count, "mission", "t");
  if (status != LUA_OK) return lua_error(L);
  lua_call(L, 0, 1);
  if (!lua_istable(L, -1)) luaL_error(L, "Module must return a handler table.");
  if (!ctx->handler[0]) {
    read_value(L, 0);
    size_t count = lua_rawlen(L, -1);
    if (count > 64) luaL_error(L, "Too many declared handlers.");
    for (size_t i = 1; i <= count; ++i) {
      lua_rawgeti(L, -1, (lua_Integer)i);
      const char *name = luaL_checkstring(L, -1);
      lua_getfield(L, -3, name);
      if (!lua_isfunction(L, -1)) luaL_error(L, "Missing declared handler: %s", name);
      lua_pop(L, 2);
    }
    write_tag(L, 2);
    return 0;
  }
  lua_getfield(L, -1, ctx->handler);
  if (!lua_isfunction(L, -1)) luaL_error(L, "Missing named handler.");
  ctx->items = 0;
  read_value(L, 0); /* event */
  read_value(L, 0); /* scoped snapshot */
  read_value(L, 0); /* explicit state copy */
  if (ctx->cursor != ctx->input_count) luaL_error(L, "Trailing input bytes.");
  lua_call(L, 3, 1);
  ctx->items = 0;
  write_value(L, -1, 0);
  return 0;
}

EMSResult ems_evaluate(const unsigned char *source, size_t source_count,
                       const char *handler, const unsigned char *input,
                       size_t input_count, EMSLimits limits) {
  EMSContext ctx = {0};
  ctx.source = source; ctx.source_count = source_count; ctx.handler = handler;
  ctx.input = input; ctx.input_count = input_count; ctx.limits = limits;
  if (!source || !handler || !input || source_count > 262144 || input_count > 1048576 ||
      limits.heap_bytes < 65536 || limits.heap_bytes > 16777216 ||
      limits.allocation_bytes < limits.heap_bytes || limits.allocation_bytes > 67108864 ||
      limits.output_bytes == 0 || limits.output_bytes > 1048576 ||
      limits.instructions < EMS_HOOK || limits.instructions > 1000000) {
    ctx.result.status = 1;
    snprintf(ctx.result.error, sizeof(ctx.result.error), "Invalid script input or limits.");
    return ctx.result;
  }
  lua_State *L = lua_newstate(allocate, &ctx, 1);
  if (!L) {
    ctx.result.status = 1;
    snprintf(ctx.result.error, sizeof(ctx.result.error), "Cannot allocate interpreter.");
    return ctx.result;
  }
  lua_sethook(L, instruction_hook, LUA_MASKCOUNT, EMS_HOOK);
  /* Pushing a zero-upvalue C function uses the initial stack; run owns all allocation-capable setup. */
  lua_pushcfunction(L, run);
  ctx.result.status = lua_pcall(L, 0, 0, 0);
  if (ctx.result.status != LUA_OK) {
    const char *error = lua_type(L, -1) == LUA_TSTRING ? lua_tostring(L, -1) : "Script execution failed.";
    snprintf(ctx.result.error, sizeof(ctx.result.error), "%.240s", error);
    free(ctx.result.bytes); ctx.result.bytes = NULL; ctx.result.count = 0;
  }
  ctx.result.instructions = ctx.instructions;
  lua_close(L);
  return ctx.result;
}

void ems_release(EMSResult *result) {
  if (result) { free(result->bytes); result->bytes = NULL; result->count = 0; }
}
