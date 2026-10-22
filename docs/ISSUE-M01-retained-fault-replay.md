# The current station-unit failure lacks an attributable stack

[Issue 88](https://github.com/stephenlclarke/elite/issues/88) remains open after exact source a561cc578e767b3e0d269282885567af8ecf0893 compiled in hosted run 39804454932, then exited with signal 4 and zero completed method PASS records. Its artifact has no matching crash reports and invalid 52-byte XML. The previous head's Game-copy stack does not attribute this failure.

The same source's original station regression passed once under the installed local Swift 6.4.1 toolchain without coverage. That diagnostic does not reproduce or qualify the original Swift 6.1.2 coverage-enabled 341-method run. Repeating source changes without a current fault location is not justified.

The retained original coverage image and matching symbols permit one configured replay without compiling product or tests. See [the diagnostic plan](PR-M01-retained-fault-replay.md). No product fix or runtime acceptance is claimed.
