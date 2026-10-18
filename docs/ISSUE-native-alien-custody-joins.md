# Close native alien ownership, history and hull-preview gaps

Source review of the native recovery/fitting slice found three missing joins. A native fragment must be exclusively cargo-owned in its actual allocated actor and producer namespaces, with original metadata and no competing NPC, EMP, mining, ordinary debris, mission or salvage owner. Independent collection operation IDs must not alias native commands, old settlement commands or original section import operations. Complete old settlement item evidence must protect spent identities even when the other section in a shared proposal has not yet been imported.

The hull exchange preview also deliberately reuses the current hull identity. Calling a real alien transfer in that preview incorrectly refuses a quote when modules are fitted; projections must preserve history, while a genuine different-hull transfer retains its permanent receipts.

Add boundary validation and negative regressions while keeping old non-native behavior, original audit records, valid command/associated receipt sharing, and honest later legacy imports. Exercise all four live stat axes, both physical energy-module kinds, repeated upgrades on one UUID, actual actor writer rollback, and native hull quotes/exchange. Source findings are not claims of an executed exploit or passing acceptance.

[PR-native-alien-custody-joins.md](PR-native-alien-custody-joins.md).

Validation 323 compiled production code but failed while compiling poisoned-body test setup: the NPC and metadata assignments wrote through game.bodies while their initializer arguments read other Game properties. Swift correctly rejects that exclusive-access overlap. Construct the identical NPC/metadata value in a local first, then perform the same assignment. No tests executed and no runtime issue was established by this compiler failure.
