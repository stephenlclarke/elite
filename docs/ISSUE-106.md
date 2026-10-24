<!-- markdownlint-disable MD013 -->
# Front-visibility renderer stack exhaustion

[Issue #106](https://github.com/stephenlclarke/elite/issues/106) records required quality run 39834119275. Compilation passed in 761.08 seconds; coverage execution ended with BUS10 and zero completed method PASS records. Thread Sanitizer, Address Sanitizer and leaks were not reached, and Sonar was skipped. PR head was 9106e701; the compiled checkout was its synthetic merge d1093408. MBA verified the relevant source bytes against the head and matched the owned process, crash report, image and dSYM.

The retained arm64 image UUID is A2531221-FAF8-3E6A-818F-0C6D5C50CBAC. The crash report identifies a stack-guard protection fault. Current disassembly places Display.draw at 0x521258; return +860 is 0x5215b4, immediately after the stack probe at 0x5215b0. This follows Game metadata and its value-witness size load, aligned dynamic Game slots, then an owned Game copy at 0x521600. Display.visibleInFront starts at 0x2ea9008; its +840 return follows the actual draw call at 0x2ea934c. The caller is real Tab target cycling through the unchanged stationAutoCoverSourceCannotBorrowAnotherAttackersActiveHazard test.

The renderer copies the entire Game only to choose a front view and force shaded startup panels. Remove those renderer-owned copies while preserving front visibility, normal demo/title shading, mesh authority, geometry, projection, clipping, materials and beams. No target ordering, filters, distances, admission, saves or simulation rules need to change. This is distinct from closed #88 and does not erase its 342-method / 379-case qualification.

See [the repair note](PR-front-visibility-render-borrow.md). Local compilation is a preflight, not qualification of the hosted crash path or full release quality gates.
