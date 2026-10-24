# test(calendar): expect native station launch bookkeeping

One existing launch test now compares the entire script state with an independently built empty state containing only the genuine station resource and exact operation-one launch adjustment from zero to 600 seconds. Default resource energy/destruction and all other script-state fields remain asserted by full equality. Original physical launch and Commander-validity predicates remain, and native world/durability are required. The method is renamed to distinguish station-calendar state from a mission; no test is skipped, removed or added. See [the obsolete assumption](ISSUE-native-launch-calendar-fixture.md).

No production calendar/resource/authority rule changes. Whole-file reversal reconstructs the original file. Independent source and Markdown review is clean; focused/full execution remains pending while frozen 222 completes; no runtime acceptance is inferred from the proposal.
