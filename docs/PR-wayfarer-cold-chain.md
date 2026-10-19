# feat(wayfarer): bind sample integrity to the existing flight timer

## Problem and behavior

MBA-04 supplies the W01 cold-chain integrity model. A caller provides an existing one-shot flight ScriptTimer and explicit finite authored allowance; no production numeric allowance is invented. Remaining integrity is max(0, native due - admitted absolute flight seconds). Paused/repeated snapshots cannot consume or reset the allowance, and serialization preserves the original due.

## Implementation

WayfarerColdChain binds owner, instance, consignment, opaque receiver resource UUID and timer identity. It rejects altered timer snapshots, invalid contexts, reversed flight clocks/revisions, stale receipt sequences and terminal reuse. A matching native timer.fired event records spoilage, including delayed native dispatch; its flight clock must reach the existing due. A structurally matching delivered courier receipt can describe reception only before that boundary. Courier proof.clock retains its existing mission-calendar meaning and never funds flight integrity. No cargo, money, mission outcome, Game state or native scheduler is mutated.

## Files and scope

The packet contains only Sources/EliteCore/WayfarerColdChain.swift, Tests/EliteCoreTests/WayfarerColdChainTests.swift, docs/ISSUE-wayfarer-cold-chain.md and this note. Base ba47c87435df08fd29f3ee980af66b106f293a5d. No existing file changes, push, merge or native jobs.

## Validation

Eleven Swift test functions AUTHORED UNRUN: pause/repeat/resume, save/load, exact due boundary, delayed timer dispatch, reception using flight instead of courier calendar time, all foreign binding components, invalid/stale/reversed snapshots, timer rearming/domain/policy, stale/foreign/early timer events, stale/foreign custody receipts and corrupt saved fields. Source hygiene and portable patch applicability are recorded separately in handoff.json. No Swift compilation, coverage, sanitizer, leak gate, make ci or Markdownlint result is claimed. G1 must compile and run focused tests and the required project gates before integration.

## Compatibility, integration and risks

Decode requires schema 1 and validates bounded native timer/context shapes and terminal consistency. This adds no commander save field or old-save fallback. MBA-05 remains required: validate actual native owner/instance/custody/receiver/clock/timer projections; join receipt provenance and current reception; admit the timer event after the director removes its once timer; serialize a successful atomic publication through existing authority. Structural validation here does not prove live provenance. An observation at due may show zero remaining pending the authoritative timer event, and reception is already forbidden. No separate expiry scheduler exists.

## Links

Issue note: ISSUE-wayfarer-cold-chain.md. UX ledger MBA-04; W01 l337.wayfarer-service/cold-chain; milestone M09; F33/K08/K09. MBA-05 owns live integration. No GitHub PR has been opened.
