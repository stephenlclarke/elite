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
