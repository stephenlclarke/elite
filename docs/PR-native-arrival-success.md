# fix(flight): require successful native arrival before publishing

## Result and implementation

`performNativeArrival()` returns `false` for the existing unsettled-wreck and salvage-persistence deferred outcomes. It returns `true` only after the actual visit, native station registration and script actor restoration complete. The private galactic-jump chain requires that success before refilling fuel or returning success to its outer publisher. Active-projectile preflight remains intact.

The ordinary arrival wrapper also requires explicit success. On a soft refusal it propagates the existing deferred message and countdown cancellation while retaining the original native candidate state. It preserves the ordinary unpaused deferred behaviour. Throwing restore failures retain the existing paused error presentation.

## Authored verification

Two new test methods define three cases. A genuinely generated native wreck is admitted through the existing runtime. The two soft-refusal cases exercise unsettled native wreck settlement and refused live salvage motion persistence through ordinary arrival and galactic jump, checking original drive, fuel, cargo, flight, bodies and salvage custody. The success case checks the actual new flight system, anchors, player/visit, arrival pose and main-station binding, as well as consumed drive, refilled fuel and retained cargo.

Formatter/parser, strict source lint, Markdown and diff/scope checks are the only local validation. These definitions have not been compiled, typechecked or executed here. G1 must run meaningful affected navigation, salvage and native arrival tests under its validation lease, followed by applicable `make ci` gates.

## Scope and compatibility

The correction is an owned child of frozen `22f2174e235fa8fb17b614569efe54d340b6874b`. It changes only Game arrival result/callers, the owned Crimbo runtime tests and this [issue/PR pair](ISSUE-native-arrival-success.md). It changes no save format, gate activation, combat law, custody producer, mission readiness or collision authority. Production Crimbo activation remains disabled pending G1's supported save/world/durability validation and native integration.

The eventual project PR must receive actual completed clean `@codex review` results and passing required checks and approvals for its final head before protected merge, without bypass.
