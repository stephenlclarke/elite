# Align full-suite fixtures with their actual boundaries

The help test checks its complete message across wrapped rows. The TOML-loader test retains explicit counts of 171 designs and 162 playable refits, independently counted from the maintained ship files. The new-commander scene test prepares canonical stock equipment before asserting complete commander equality after loading.

The invalid-binding frame test captures the actual actor-published state after constructor initialization and requires its whole commander, bodies, clocks, allocator, revision, energy and cooldown to remain unchanged on refused advancement. It also requires the constructor's real calendar and unchanged initial bodies and time. Retained projectile construction and legacy-impact verification run in separate functions; their original setup and all attribution, damage, event, no-bounty and replay assertions remain intact.

Source formatting and whitespace checks pass. The exact original failing binary and diagnostic stop are retained under `/tmp/elite-debug-crash-141`. Targeted execution and full CI remain pending; no skipped tests, synthetic hits, relaxed guards or stack flags are introduced. Motivation: [issue](ISSUE-full-suite-compatibility-fixtures.md).
