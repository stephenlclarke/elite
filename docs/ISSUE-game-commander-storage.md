# Launch stack pressure with thread instrumentation

The complete coverage phase at `1a9bd79a53896f55ec883027e2e9e8085dc79f00` passed 1,669 methods with four existing GPU skips and 95.90% coverage. The maintained thread-sanitizer phase exited with signal 4 before a complete result; address-sanitizer and leak gates did not run. Its exact binary and objects were preserved.

Diagnostic 232 used that same binary without rebuilding. An actual actor/key launch crossed the mapped stack boundary while copying Game during station population. The debugger recorded SP in a non-readable guard region and FP in the adjacent writable stack. This establishes that diagnostic's stack fault; it does not establish an OS-level equivalence to the original run's signal. Actual dynamic reservations exceed the small static function prologues.

Keep Game value semantics, Swift 6 checked Sendable, actor ownership, existing public commander access and Commander encoding. Replace its inline Commander with private single-element array storage whose read/modify accessors use checked copy-on-write. Retain the actual launch, admission, station validation and command rollback paths, test nested snapshot independence, then run affected instrumentation and final full gates.
