# Missing direct runtime fault stack in hosted quality output

Required quality run 39500039720 at committed e1b7fd29 compiled with Swift 6.1.2/Xcode 16.4, then make ci exited 2 with unexpected signal 10. No conclusive method terminals, final test summary or crash-report candidate was retained. Both fixed report roots were successfully observed without a new candidate during the bounded window. There is no original body to symbolicate and no supported fault-site attribution from the last interleaved test name.

The existing launcher pipes stderr into ci.log and inherits the host environment without explicitly enabling Swift's crash backtracer. The upstream Swift 6.1.2 macOS runtime defaults to TTY-dependent capture, which is disabled on a pipe. Explicit child-only, noninteractive runtime backtracing can provide the actual fault context directly to the already retained stream when supported by the actual installed helper. This is an evidence change, not an engine crash repair.

Acceptance requires preserving the original make ci command, default suite, process-session ownership, exit status, collection limits, report parser and strict attribution. Only the fixed SWIFT_BACKTRACE setting is recorded, never the complete inherited environment. The next normal required CI supplies actual runtime evidence after independent review; no local native probe or unchanged-head retry is part of this change. If that run proves runtime refusal, preserve the refusal and investigate a separately reviewed mechanism instead of blindly repeating environment-only runs.

See [implementation and validation](PR-direct-runtime-backtrace.md).
