# Bound crew-log selection body ownership and metadata lifetimes

## Motivation and evidence

[Issue164](https://github.com/stephenlclarke/elite/issues/164) records the distinct `c23e2e1c` guard fault during original delayed-report patrol target selection. Build66.44seconds passed; the four-method process exited1/rawSIGBUS10 after78.345295375seconds, with all methods only started, no terminal completion/assertion and unfinished52-byte XML. Existing `/tmp/elite-163-alias-focused` artifacts retain source/result/report/image evidence.

Matched PID35961 (launch21:15:35.0594, capture21:15:46.3606UTC) reaches dyld/conformance/dynamic cast, Data initialization and ScriptIdentity.uuid, then crew-log actor/markerJob, recorder/facts/metadata and work-target selection. Fault0x16f087fe0 lies inside guard0x16f084000-0x16f088000; SP0x16f088010 is just above it. There is no chkstk or Game/Commander copy frame. Loaded image5DC21BA9-E202-3D5E-9093-B5ED80F81DEB matches collected metadata/SHA256d6d1d067f836f2917d8caa25a0cbaa3a125378ffa6d3e419609ec59bc0aabc56; SHA remains collector-provided. This identifies guard access on that path, not a UUID/hash/conformance policy defect or a163 alias recurrence.

## Implementation

Borrow SpaceBody through existing recorder, marker-address and complete authority helpers, plus facts/metadata entrypoints. Make recorder/facts/metadata entries noninline. Preserve original marker lookup and complete eligibility/read order. Copy the exact body only when publishing the original owned actor body. Finish facts eligibility before a separate noninline metadata phase invokes the same owned mesh API and constructs identical bounds/metadata. Copy body at that original owned mesh boundary only after facts succeeds. Marker identity/hash equality, Commander/full physical/mission/fit/custody validation, fits calculation and all payload fields remain unchanged.

## Validation

Strict Swift formatting and diff hygiene pass. Independent actual-source review and one cached Swift6.1.2/SDK15.5 execution of the same four unfinished original delayed-report, authentic station-entry, board-browsing and targeting price/persistence methods are pending. No new selector, hash shortcut, probe or broader campaign is introduced. Earlier three ec83 individual passes remain separate receipts; no synthetic aggregate result is claimed.

## Compatibility and remaining limits

No Game state, actor boundary, save/schema, authority, marker/hash, UI, reward or quality threshold changes. No source-only proof of stack savings/runtime success is claimed. Current required quality, completed-save/reopen proof, coverage/sanitizer/leak gates and release remain unqualified.

## First focused execution

The `47700106` Swift6.1.2/SDK15.5 build passed in70.81seconds; four-method process failed exit1/rawSIGBUS10 after82.665024791seconds. All methods only started, with no completion/assertion results and unfinished52-byte XML. Existing `/tmp/elite-164-selection-focused` artifacts retain actual source/result, normal report and exact image metadata. Independent actual-source review is clear; current fault attribution and runtime qualification remain pending.

## Combined checkpoint result

The source-reviewed combined159-168 packet `eb5ab2d8` compiled successfully, then its one normal four-original-method batch failed signal10/exit1 after198.327703625seconds with zero completed methods/assertions. No matching normal report exists; the separate exact-image capture is diagnostic only. No issue is closed or runtime-qualified by source review. [The combined packet inventory](PR-25-M01-RELEASE-BLOCKERS.md) records exact source, evidence limits, retained unaffected passes and remaining required gates.

## Current marker eligibility follow-up

The single corrected diagnostic capture at `b611d932` retains module slide0x11174c000 and the exact EDA40267-E98B-3F03-B8CD-63AD5C54144B image, independently matched to SHA25664460dea2e9be39704c2c13bbf9273a98939ce034ff7f49218cb96968fe0fb0c. Offline symbolization identifies crew-log actor/markerJob hashing through recorder facts/metadata and auto-target selection in the original delayed-report method. The stop is `_availability_version_check+8`; no guard mapping or chkstk/copy top is saved, so the exact failing buffer and earlier normal crash causes remain unproven. `/tmp/elite-m01-offset-owned-capture` retains identity, stack, offsets and result; the guest retains the exact binary. This14.147784541-second diagnostic exited driver1/debugger0, detached successfully and left no owned process. It is not a test pass.

Recorder selection now requires the two body mission identifiers, then applies the identical retained-child definition/digest/authorization marker predicate before deriving the actor UUID. A false retained-child predicate was already an inevitable refusal. Eligible children still require the unchanged derived actor equality and complete recorder authority. No hash input, UUID policy, cache, mutable state, save format or selection order changes. Existing boundary cases now also cover missing retained child, definition/digest mismatches, and missing/mismatched authorization, with recorder/facts/metadata refusal and unchanged Commander assertions. Original four-method and boundary execution results are pending.
