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

## First focused execution

The `7771f9bb` Swift6.1.2/SDK15.5 build passed in199.87seconds; four-method process failed exit1/rawSIGBUS10 after211.6990105seconds. All methods only started, without completion/assertion results; XML remains unfinished52bytes. Existing `/tmp/elite-165-custody-focused` artifacts retain exact source/result, normal report and collected image metadata. Source review is clear; current fault attribution and runtime qualification remain pending.

## Current report identity limitation

The newest normal report initially collected after `7771f9bb` was stale: previous47700106 PID36026/image65F3BF1E rather than current imageF26BBE52-820B-35A5-9455-1FE55BD7EC63/SHA256f859890fea35bb48d70d85c6d31d4640a979633b5cfb4cd31377892b2f0af5b3. A read-only recursive inventory of27 retained swiftpm helper reports in guest user and system DiagnosticReports found no matching current UUID. The stale file is explicitly retained as `/tmp/elite-165-custody-focused-stale-477-report.ips`; image metadata marks the mismatch. No current fault location or165 recurrence is established. The actual compiler pass/runtime SIGBUS/four incomplete methods remain the valid receipt. No new capture, debugger probe or execution was used to fill the missing attribution.

## Combined checkpoint result

The source-reviewed combined159-168 packet `eb5ab2d8` compiled successfully, then its one normal four-original-method batch failed signal10/exit1 after198.327703625seconds with zero completed methods/assertions. No matching normal report exists; the separate exact-image capture is diagnostic only. No issue is closed or runtime-qualified by source review. [The combined packet inventory](PR-25-M01-RELEASE-BLOCKERS.md) records exact source, evidence limits, retained unaffected passes and remaining required gates.
