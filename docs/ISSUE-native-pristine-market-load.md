# Loading an unchanged world materializes a pristine market

The actual659 PLUGH regression recorded unequal full Commander values and changed native-save pointer bytes after an ordinary public load. The retained failure values identify a new G03-S256 entry in OriginalLiveMarkets.changed: its quotes and quantities equal the authenticated pristine PLUGH market. The saved Commander previously resolved that market without an owned mutation.

restoreScriptWorld assigns its market snapshot unconditionally. The Game.market setter records an owned market entry even when its value already matches the current resolved Commander market. This introduces a semantic save difference during restoration and triggers republication. The full Commander and exact pointer-byte checks correctly expose it and must remain. See [the change and validation](PR-native-pristine-market-load.md).
