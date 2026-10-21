# fix: shorten terminal plasma fixture stack lifetime

## Result

The shared contact fixture calls a private terminal-preparation helper only when the existing terminalPreDamage condition is true. The helper borrows the same Game by inout and performs the identical native pre-damage sequence before returning to the original sealed-contact producer. It creates no Game copy or replacement state.

## Scope and compatibility

All ten original methods and thirteen cases remain unchanged. The helper body reverses exactly to the former block after substituting its projectileDamage parameter with the original weapon.damage expression. The rest of the whole original test file must match byte for byte. Production, source rock metadata, controls, timing, damage, queues and terminal/replay oracles are unchanged.

## Validation

Validation 360 is a retained stack-guard crash, with every case outcome unknown. The old and failed binary prologues establish a 7,376-byte increase in the shared local frame. This source-only child has no compiler, runtime, sanitizer or coverage acceptance; independent source review and one affected execution remain required. See [motivation](ISSUE-plasma-fixture-frame-lifetime.md).
