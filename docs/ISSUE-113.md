<!-- markdownlint-disable MD013 -->
# Navigation availability tests retain an obsolete refusal message

[Issue #113](https://github.com/stephenlclarke/elite/issues/113) tracks three stale exact-message assertions exposed by the focused availability run for [PR #107](https://github.com/stephenlclarke/elite/pull/107). The production navigation runtime intentionally introduced separate route-record restoration and chart-selection guidance in fc214b89. The test and navigation runtime are byte-identical to the pre-refactor 7d67 baseline; the availability extraction did not change these messages or their priority.

Correct only the expected exact strings: invalid explicit binding requires route-record restoration, while selecting the current system requires selecting a different reachable destination. Preserve the explicit valid-binding success, default-binding success, claim applicability, first-refusal order, and durable-save refusal assertions. Add the two existing navigation test methods to the maintained isolated-unit selection, which previously omitted them. Keep all other selected methods.

See [the repair note](PR-navigation-availability-oracles.md). The original failed three assertions remain recorded; no production policy change or weaker substring assertion is needed.
