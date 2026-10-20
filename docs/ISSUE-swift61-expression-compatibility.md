# Swift 6.1 cannot compile nine newly composed expressions

## Observed failure

Hosted quality run 39420064038 for source fb4a9c47550b0c87949af65296667248332893ac stopped while compiling the mission-packs-check prerequisite with Xcode 16.4 / Swift 6.1.2. The full log identifies eight solver-timeout expressions and one Int-to-UInt16 inference error across eight source files. Runtime mission validation, coverage, sanitizers and leak gates were not reached. This is an actual compiler failure, not nine demonstrated runtime defects.

## Bounded correction

Decompose only those nine expressions with explicit intermediate types, ordered appends and short lazy fallback groups. Preserve texture byte packing and bounds, display strings and order, quote/review priority and short-circuiting, gallery proof fields and diagnostic bit values. Leave simulation advance, save/loader control flow, mission policy, renderer behavior, caches and CI configuration unchanged.

## Acceptance and limits

Existing focused tests already cover native save refusal bits, contract page identity, gallery layout/proofs, navigation accounting and texture loading/rendering. Original texture coverage reconstructs every packed byte and compares the pinned digest. No new mirrored implementation test is needed for this decomposition. G1 owns one matching focused build and the selected existing cases; local Swift 6.4 cannot establish older-compiler acceptance. The final integrated head must pass actual hosted Swift 6.1 CI. Preserve the failed hosted result. No remote PR is created by this author packet. Companion: [PR-swift61-expression-compatibility.md](PR-swift61-expression-compatibility.md).
