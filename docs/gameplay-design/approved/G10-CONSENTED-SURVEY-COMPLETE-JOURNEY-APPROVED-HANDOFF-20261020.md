# G10: approved complete consented orbital survey handoff

Root approved this next queued MBA item on 20 October 2026, after qualified integrated G14. This records the existing source-backed handoff and approval; it is not a new design, an implementation assignment or permission to edit shared source now.

## Scope and source authority

**G10 / M06 / F17-F20 / K08 / K11**, exact family `l337.contract/consented-survey`.

Player deliverable: accept permission to survey three registered physical calibration targets, perform a distinct 12-second qualified native scan of each, return the signed measurements to the actual issuer/receiver, and receive the frozen reward and this family's clue once. Deliver the complete installed pack, station board, native operation, HUD, receiving transaction and current save boundary. A standalone scan SDK is insufficient.

Existing authored sources in this UX workspace:

- original-missions/original-families.json and original-families.md, exact G10.
- original-missions/ENGINE-CONTRACT.md.
- Existing G10 service and clue artwork referenced by that template.
- Retained historical source-only reconciliation: /tmp/elite-g3-MBA09-scan-workshop-decision/proposal.json.

The source preflight examined canonical **78e0290fe98b6774cb18b2341bd0ae3fab40c3ec** at /Users/sclarke/.codex/worktrees/canonical-integration-recovery/elite. This is an examined checkpoint, not the eventual post-G14 implementation base.

Authored requirements: three distinct registered ship-accessible calibration points at advertised safe ranges; 12-second scans; zero additional cargo, berths, deposit or donation; untimed ordinary offer; reward **540 + 95L + 80H CR**. Exact first-success clue: **consented-survey-family-trace**. Actual successful receiving settlement alone grants it, once. Acceptance, partial scans, failure or another family cannot substitute.

## Approved ordinary defaults

Root approved these previously proposed defaults; distinguish them from the authored template:

- Actual Avenor G0/S7 issuer -> three G10-owned Renas G0/S185 calibration markers -> actual Avenor receiving office.
- Native route L2, H0, frozen reward **730 CR / 7300 native**.
- Zero cargo, passengers, berths, deposit and deadline.
- Three new G10 marker identities/aliases and issuer permission. Use the existing supported G05 SH040 noncombat marker geometry/deployment pattern, without using G05 actor identity or authority.
- A declared order of three distinct targets; 12 continuous qualified native seconds per target.
- Surface range 250-1500 native flight units, 2-degree front-view boresight, actual nearest-hit line of sight, maximum admitted physical interval 0.1 seconds.
- Pause freezes observation; interruption or load resets unfinished dwell, while completed readings persist.
- Existing fitted targeting-computer observation. Preserve W/Return/E/Q; no new keyboard action or FlightWorkTools change is proposed.
- The third scan alone pays nothing. Return the measurements to the genuine receiving office for the terminal settlement.

Freeze supported collision-clear native target poses before owner qualification. Source/template checks do not establish that untested coordinates are safe. No new hull, renderer, people/cargo framework or mission research is needed.

## Why this is next

G01/G02/G03/G13 in M05 already have bounded qualified source. G04/G05/G08 and current G14 have their own complete journey work. G10 is the earliest remaining unimplemented generated family in M06.

The earlier MBA09 survey proposal was parked because the actual native observation producer was missing and its frame/tool hooks were reserved. Qualified G05 now supplies a concrete native observation pattern:

- Game.advance takes an actual pre-motion sample, runs native tick/station entry and commits the native observation.
- NativeOrbitalOutlookScan.swift measures actual qualified intervals with raycast and fitted-equipment witnesses.
- Completed measurements use the existing writer/publication boundary, historical authority validation and current load/cull handling.

G05 remains closed to its passenger source and boarding. G10 must have its own permission, target registration, operation and measurement records. Do not use G05 people, cabins, boarding, actor authority or completion receipts to manufacture a survey.

Do not revive the historical proposal's rejected legacy-workshop fallback or introduce a telemetry-only dwell timer.

## Complete journey and native boundary

At the actual Avenor station, the ordinary board presents the real permission, exact target set, fitted-equipment requirements, route, interruption policy and frozen reward. Reading, Back or a stale review transfers nothing. Acceptance registers the G10 targets and job through the actual durable command path.

Actual selected-target observation qualifies each distinct G10 actor against the current owner/carrier, fitted targeting equipment, inventory revision, system/visit, physical pose/range/aim and nearest raycast hit. Only measured native frame intervals count. A UI read, repeated sample, caller-supplied elapsed time or mission flag cannot supply dwell.

Keep incomplete runtime dwell separate from committed completed readings. Target switching, failed sight, invalid geometry, destruction, culling or load cannot backfill time or manufacture a reading. Retain completed original measurements and their historical authority honestly through current saves and actor rebinding.

At the actual Avenor receiving office, require all three genuine G10 measurements and the current native receiving context. Commit final outcome, frozen payment and exact first-success clue atomically. Two readings, a G05 record, another target, a wrong receiver or a replayed terminal cannot settle.

Writer refusal/retry at acceptance, measurement and settlement conserves source, measurements, operation identity, cash and clue without inventing native intervals. No general proof framework or caller-granted scan authority.

## Conditional ownership and predecessor

**Predecessor:** G14 must be owner-qualified, independently clean-reviewed and integrated by G1. G10 is queued, not assigned.

Root reserves **49 Normal / 50 Alien conditionally after G14's 47/48**. A genuine G10-only state validates independently; composed family and Alien attachment claims each require their own real evidence. No fake G04/G05/G08/G14 claim, old-envelope widening or predecessor-format migration.

Root approved the prospective 24-path boundary below, plus the subsequent G1 ledger assignment record. The Game.swift and ScriptMissionState.swift hooks remain **conditional on exact post-G14 source preflight and ownership availability**. There is no current edit permission. Avoid G1's M01 release/runtime and G2's fixture-triage ownership.

Required shared hunks are concrete:

- Game.swift: only bounded optional survey runtime/reset and the G10 pre/post-native-frame calls beside the existing G05 observation calls.
- ScriptMissionState.swift: only typed optional current G10 survey state/accessor/Codable joins within its existing COW storage.

Do not change their unrelated behavior, storage shape or G05/G08/G14 validation. If Root cannot reserve these exact hooks after G14, keep G10 queued rather than bypassing native authority. Exact additional production callers require Root's path/hunk approval before editing.

## Prospective 24 implementation paths

Four new helpers:

- Sources/EliteCore/NativeOriginalSurvey.swift
- Sources/EliteCore/NativeOriginalSurveyBoard.swift
- Sources/EliteCore/NativeOriginalSurveyScan.swift
- Sources/EliteCore/NativeOriginalSurveySave.swift

Thirteen existing bounded consumers:

- Sources/EliteCore/Game.swift
- Sources/EliteCore/ScriptMissionState.swift
- Sources/EliteCore/ContractBoard.swift
- Sources/EliteCore/ContractBoardDisplay.swift
- Sources/EliteCore/ScriptContractPageInput.swift
- Sources/EliteCore/ScriptPack.swift
- Sources/EliteCore/ScriptCommanderQuery.swift
- Sources/EliteCore/ScriptPersistence.swift
- Sources/EliteCore/ScriptSaveJSONPreflight.swift
- Sources/EliteCore/ScriptBundledPacks.swift
- Sources/EliteCore/ScriptBaseClueCatalog.swift
- Sources/EliteCore/TargetPanel.swift
- Tests/EliteCoreTests/BundledScriptPackTests.swift

Seven new qualification/content/notes files:

- Tests/EliteCoreTests/NativeOriginalSurveyJourneyTests.swift
- Tests/EliteCoreTests/NativeOriginalSurveyScanTests.swift
- Tests/EliteCoreTests/NativeOriginalSurveySaveTests.swift
- Sources/EliteCore/Resources/ScriptPacks/l337-consented-survey/manifest.toml
- Sources/EliteCore/Resources/ScriptPacks/l337-consented-survey/scripts/main.lua
- docs/ISSUE-original-consented-survey.md
- docs/PR-original-consented-survey.md

These are prospective names and boundaries, not existing APIs or permission to touch canonical source. Drop unnecessary paths during the exact preflight; reserve additional actual paths with Root. G1 alone updates the canonical assignment/index/ledger and integrates approved material.

## Meaningful owner acceptance

1. Actual board permission, fitting, quote, Back and three exact target registrations. No source transfer from reading.
2. Actual qualified native 12-second observation yields one exact reading. Duplicate/synthetic elapsed time, wrong target, occlusion, death/culling or missing equipment cannot supply it.
3. Switching, pause, load or visit discontinuity preserves completed readings and resets unfinished dwell as advertised.
4. Genuine final native dock/measurement reception pays the frozen reward and exact clue once. Partial, wrong-family, wrong-target, wrong-receiver and replayed evidence refuses.
5. Actual writer refusal/retry at acceptance, measurement and settlement conserves native evidence/cash/clue without fabricated frames.
6. Genuine G10-only and composed Normal/Alien cold saves retain exact joins. Malformed, stripped, foreign and old-envelope claims refuse.

The implementation owner obtains meaningful focused unit PASS and actual pack CLI/digest qualification, then one independent coherent bugs/performance/style CLEAN review before G1 integration. A frozen source-only packet is not integration-ready.

Use the isolated MBA cache and bounded matching build/focused checks only under Root's execution lease. No GUI, full CI, profiling or rerun of unaffected passing cohorts. No current build, test or implementation is started by this document.

## Existing next-two backlog candidates

These are queue candidates, not assigned work.

1. **G09 / M08 / l337.contract/identified-salvage.** Two original tonnes in a real orbital wreck cradle -> actual collection -> consenting owner's receiver. Authored 650 + 115L + 80H CR; zero berths/deposit, untimed. Qualified G08 provides a physical-record capture/cargo/publication pattern, but G09 needs its own two-item source, cradle, owner permission and receiving/custody/save proofs. Never broaden G08's closed rescue authority or use a capsule as a salvage item. Exact source seams need separate Root reservation.
2. **W05 / M08 / l337.wayfarer-service/record-recovery.** Identify a unique physical 1t recorder while it remains in its cradle -> actual recovery once -> same recorder to its real custodian. Authored 460 + 95L + 130H CR, zero berths. Existing original-missions/wayfarer-services.json is the design authority. Preserve ordinary visible qualification, shared three-service cap, stable quote, real custody and distinct exchange-service-record-recovery clue. No living-survivor receipt or hidden accreditation gate for the ordinary variant. G08/G09 patterns help; they do not implement W05 automatically.

Dependency-aware exclusions: M07/G15 also requires an actual civilian safe-arrival producer; G06/G07 kills and G14's player-carried people do not prove NPC civilian flight arrival. G11 remains parked on genuine programmer/two-module physical isolation providers. G12 needs extraction/refining provenance. These are not lighter ready substitutes.

Root alone dispatches. Researcher-origin campaign design continues only through Root to Mission Coder1. Do not message coders, assign these candidates or expand the queue from this handoff.
