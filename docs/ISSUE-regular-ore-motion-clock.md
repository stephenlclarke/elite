# Retain physical motion while ordinary ore awaits admission

Ordinary released ore has a nonzero velocity but its pending spawn proposals reuse the same stored position through refusal and culling. Only breakup descendants retain a snapshot epoch and advance unbound material by elapsed physical time. This can keep a moving regular payload proposed at a stale obstructed location.

Actual G12 run 1261 on private 4bdb18b12b56897441d94b53f393aeea00282606 stopped at ten of twelve captures when its sixty-second physical admission wait expired. It naturally failed its test, not the outer native watchdog. Its pending10/bound8 counters do not identify the two unbound payloads or any individual refusal reason. The ordinary-motion defect is source-proven; the complete cause of the remaining two-original acceptance gap is not observed.

## Bounded repair

Keep one required snapshot epoch for every regular pending payload in MiningLedger. Anchor births with existing incident/native-motion clocks. Advance only unbound regular proposals by velocity times elapsed physical time; retain every existing birth position, identity, amount and velocity. Current actor writes require a finite monotonic clock. Refusal, cull and reset preserve the latest snapshot; settlement and departure remove its clock with its payload.

Current-format decoding requires exact matching bounded clock records. Missing, orphaned, duplicate, negative or oversized records are rejected. No backwards decoder, migration, invented historical timestamp or first-observation fallback is supplied. Existing production writers already pass their physical clock; no additional production path changes are needed.

Breakup handling, admission guards, ordinary/reserved population limits, geometry/collision checks, protected-original rules, the twelve-original goal and recovery deadline remain unchanged. This change introduces no new diagnostics or native flight loop.

## Validation

MBA source formatting and strict lint, copied source hashes, ASCII, Markdown, whitespace and the exact seven owned paths are checked at freeze. Two short deterministic ledger regressions cover refused retry intervals/cold load and timed cull/stale writer/settlement. Existing short controls cover actor authority, current-save validation, collection and presence history. The approved fixtures that issued at time1/2 but offered at time0 are corrected locally; the global ecology helper is unchanged.

No author compiler/native/CI job runs. G1 owns matching compilation and focused actual execution when its priority slot is available. One complete independent review follows focused owner PASS. Actual twelve-original journey acceptance remains pending separate Root/G1 dispatch; this source change is not proof of twelve recovered originals.
