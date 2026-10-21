# Observe the remaining historical format-21 whole-value difference

Validation 318 completed 46 passing methods and five failing methods. The genuine historical format-21 migration reached current format-26 publication but its complete expected Commander differed after save and reload. Preserve the original expected value and identify the actual changed fields before adjusting fixture expectations or production behaviour.

The exact validation-318 binary and 699 compiled artifacts are preserved before any rebuild. The observation must reuse only this existing failing method, keep its complete equality checks, and record supplemental typed state equality and encoded field deltas. No gameplay, loader, ownership or save guard changes.

[PR-historical-save-mirror-observation.md](PR-historical-save-mirror-observation.md).
