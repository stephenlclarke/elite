# Loading an unchanged world materializes a pristine market

The actual659 PLUGH regression recorded unequal full Commander values and changed native-save pointer bytes after an ordinary public load. The retained failure values identify a new G03-S256 entry in OriginalLiveMarkets.changed: its quotes and quantities equal the authenticated pristine PLUGH market. The saved Commander previously resolved that market without an owned mutation.

restoreScriptWorld assigns its market snapshot unconditionally. The Game.market setter records an owned market entry even when its value already matches the current resolved Commander market. This introduces a semantic save difference during restoration and triggers republication. The full Commander and exact pointer-byte checks correctly expose it and must remain. See [the change and validation](PR-native-pristine-market-load.md).

## Latest central execution

Central run 661 at committed source c06c672a4e62f6e163d9ba36113c9dc918286774 completed all four selected methods and eight source cases with no errors, unknown outcomes, crashes or timeouts. The previously crashing unresolved-world request/save path, full PLUGH current-format live/disk Commander and default-public-load exact-pointer assertions, and all six basic/paid-extended route-pool cases passed. Evidence: /tmp/elite-station-qualification-661/agent-game-test-verification-661.json (SHA256 90facc6d3bd158fe34884a24357979f1c06e24b5be4d84826d1508f7918545f6). This is focused native evidence; earlier interrupted NPC departures, player cohorts and physics outcomes remain unqualified. Actual signed-app launch/save/load/hyperspace verification and final required gates are separate pending delivery steps.
