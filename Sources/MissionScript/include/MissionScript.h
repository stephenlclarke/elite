#ifndef ELITE_MISSION_SCRIPT_H
#define ELITE_MISSION_SCRIPT_H
#include <stddef.h>
#include <stdint.h>

typedef struct {
  uint64_t instructions;
  size_t heap_bytes;
  size_t allocation_bytes;
  size_t output_bytes;
} EMSLimits;

typedef struct {
  unsigned char *bytes;
  size_t count;
  uint64_t instructions;
  size_t peak_heap_bytes;
  int status;
  char error[256];
} EMSResult;

/* All Lua operations, including callbacks and error unwinding, stay in C. */
EMSResult ems_evaluate(const unsigned char *source, size_t source_count,
                       const char *handler, const unsigned char *input,
                       size_t input_count, EMSLimits limits);
void ems_release(EMSResult *result);
#endif
