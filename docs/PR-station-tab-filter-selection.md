# test: identify failed station Tab engagement stages

Give each of the four existing main-station Tab engagements a descriptive stage. Before cycling, require undocked, unpaused flight, the unchanged ships filter and fitted military core, and a living main station physically bound to the canonical anchor with a valid model orientation. Retain the original finite scan and exact station-zero plus docking assertion; include actual selection IDs, screen, pause state and notification in its failure message.

Helper preconditions and diagnostic strings are evaluated into local values before Testing macros, so their implicit comment closures do not capture Game. This is a diagnostic handoff, not a claimed fix for 687. Authentic traffic and station custody remain untouched, as do hardware/filter behavior, removed-C checks, cancellation, real docking and the original 2,500-step budget. No production code changes. See ISSUE-station-tab-filter-selection.md.

Validation is strict Swift formatting, Markdown lint and git diff --check only. ZERO compiler, native, GUI, CI or probe jobs run. Runtime cause and acceptance remain unresolved pending the integrator's next authorized coherent cohort; no standalone rerun is requested.

Actual group 690 localized the failure to reengagement after P, not initial engagement: selections 11, 12, 10, 11, 1, 12, front screen, unpaused, AUTO TARGETING ENGAGED. The exact main-zero/docking assertion still failed. Proof SHA256 `5b76d0bbd965ba31c35731d178996ba0618924f03f70931443bb03453becb0b2`. Subsequent failure-only eligibility diagnostics remain unexecuted and do not resolve that failure.
