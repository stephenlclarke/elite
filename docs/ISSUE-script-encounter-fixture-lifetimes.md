# Patrol fixture admission overlaps future verification buffers

## Actual evidence

Debugger checkpoint 212 using the preserved checkpoint 211 coverage binary stopped in `sameFrameFatalHitBeforeDockRecordsDeathAndOrdinaryBountyExactlyOnce`, through `patrolGame` event emission, encounter admission and admission-source construction at a stack probe. Source is `f0f90e24b2ec616058926d2c9de34471ca9f928f`; binary SHA-256 is `5f52b1f5fd58c34f80857b824089905b29669268f016975da683bed9e7c6a95d`. The fault lies eight bytes below the reported readable/writable region. This is not independently measured pthread stack size or proof of equivalence to the original 211 signal.

## Bounded source and emitted findings

The failing test reserves four named Game buffers and one Commander buffer before calling the fixture; its fixed frame is 4688 bytes plus 48 saved-register bytes. Subsequent actual-actor, contact, laser and assertion work accounts for future verification lifetimes. The fixture itself has one required Game buffer and remains unchanged.

Five other synchronous callers in this file also reserve future Game or Commander verification buffers before this factory: foreign-event/culling checks, native completion rollback, missing station reference, physical save consistency and new-Commander scene isolation. The jump caller has only its required Game buffer; asynchronous caller buffers belong to task storage. Those unconfirmed or unrelated callers are excluded.

## Required preservation and limits

Keep the same fixture, actual admission, commands, contact/origin/hit, bounty, docking, reload and rollback assertions. Move only each selected caller's post-fixture remainder into an inout verification phase. No Core change, stack option, boxing, serialization, skip or expected-outcome change is justified. Source preservation does not establish emitted savings or crash resolution. See [the implementation](PR-script-encounter-fixture-lifetimes.md).
