# Refuse absent custody before original-rescue body projections

## Motivation and evidence

[Issue165](https://github.com/stephenlclarke/elite/issues/165) records the distinct `47700106` original-rescue selection guard fault. Swift6.1.2/SDK15.5 build70.81seconds passed; four-method process failed exit1/rawSIGBUS10 after82.665024791seconds. All methods only started, with no completion/assertion and unfinished52-byte XML. `/tmp/elite-164-selection-focused` artifacts retain actual source/result/report/image evidence.

Matched PID36026 (launch21:19:51.7726, capture21:20:03.0096UTC) stops at chkstk then originalRescueFactsForMissionBody+168, through facts/metadata/work-target selection in original delayed report. Fault0x16bee3ff8 lies inside guard0x16bee0000-0x16bee4000; SP0x16bee4990 is above it. No Game/Commander copy or crew-log frame appears. Loaded image65F3BF1E-D000-3E19-B663-BD7E47BC174C matches collector metadata/SHA256c5577caa67091d681830b858de886f367656ebad010f83c025879749ac4eef1a. The SHA remains collector-provided; no precise helper field/statement is attributed or earlier issue completion inferred.

## Implementation

A narrow noninline Commander query checks the existing custody storage and its optional-value tag without constructing the custody payload. Absent storage or a retained nil value returns false, matching original nativePeople absence. The original mission-body facts entry refuses absent custody before reserving owned body/currentBodies/Commander-closure projections; a separate noninline present-custody phase contains those exact original projections and full static authority call.

This presence check only proves a necessary refusal condition, never rescue eligibility. Every present case still runs the entire unchanged eligibleOriginalRescueFacts state/terminal/owner/version/digest/carrier/registration, actor/physical/spawn/context/logical/consumed/live-fit, duplicate-count, custody and capacity policy. No predicate is removed or replaced with the header. Pure body projections now occur only after the same necessary custody existence condition; no mutation or asynchronous interleaving is introduced. No additional state is captured/cached and existing read/result order otherwise remains intact.

## Validation

Strict Swift formatting and diff hygiene pass. Independent actual-source review and the same four unfinished original delayed-report, authentic-entry, board-browsing and targeting-price/persistence methods on cached Swift6.1.2/SDK15.5 are pending. No new selector, diagnostic probe or broader campaign is introduced. Prior ec83 individual passes retain their distinct source/results.

## Compatibility and remaining limits

No storage/schema/encoding/equality field, actor boundary, Game state, custody authority or quality gate changes. Runtime/stack savings and earlier issue closure are unestablished until actual original methods complete. Required full coverage/sanitizer/leak checks, completed-save/reopen proof and release remain pending.
