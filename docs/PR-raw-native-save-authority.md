# Reject native station custody in legacy raw saves

## Change

The raw-Commander JSON preflight rejects non-null `nativeStations` and `savedContracts.rrs` before Commander decoding. These new native fields require the versioned retained-world save boundary. The versioned loader and current docking, settlement and writer checks are unchanged. Absent and explicit-null optional fields remain compatible with ordinary legacy saves.

## Regression coverage

`RawNativeSaveAuthorityTests` adds seven cases across four methods:

- `rawPureLedgerDockCannotRestoreNativeAuthority(main:)`: RRS and original-main cases construct structurally valid pure-ledger receipts without native doorway entry, encode raw Commander JSON and require actual load refusal. Both compare the complete live Commander, sorted encoded retained world, previous save-tree bytes and raw input bytes after rejection.
- `genuineVersionedDockStillRestoresNativeAuthority(main:)`: RRS and original-main cases cross their actual doorways through `GameRuntime.advance`, use the real versioned writer, then reload. The complete Commander and previous files remain unchanged, the runtime epoch changes, and the applicable service or arrival context remains available.
- `ordinaryLegacySaveWithoutStationStateStillLoads(explicitNull:)`: absent and explicit-null station/RRS cases use the actual legacy loader, preserve property and input bytes, and create no docking authority.
- `rawRRSCustodyWithoutStationWorldIsRejectedBeforeCommanderDecode`: the typed RRS field is rejected independently of station-world presence.

The native entry fixtures reuse existing source geometry and runtime movement. Pure-ledger construction appears only in rejection fixtures. No production receipt constructor or restoration rule is weakened.

## Validation

Strict Swift formatting, Markdown lint and diff checks pass. Compilation and runtime execution are intentionally deferred while Root's full validation lease is active. Root must execute all seven cases and the existing station/courier restoration regressions before final composed `make ci`; authored cases are not passing evidence.

## Compatibility and review

The raw preflight checks only native schema paths, preserving authored payload keys and the versioned save path. Existing legitimate native station/RRS saves already require the simulation calendar and versioned writer. Review the actual legacy-input rejection and versioned positive cases together. No merge, publication or release is claimed; completed external review and final-head checks remain required.

Motivation: [legacy save authority issue](ISSUE-raw-native-save-authority.md).

## Compiler follow-up

Checkpoint 180 failed during test discovery compilation: the negative main-dock fixture modified `game.commander.nativeStations` while reading `game.commander.scriptState.calendarSeconds` in the same assignment. The fixture now snapshots that actual primitive clock value immediately before the assignment, after the same Boolean dock call. Receipt data, allocation order, refusal and conservation assertions are unchanged; no production code or calendar policy changes. The failure proof is `/tmp/elite-full-review-ci-180/root-discovery-failure-180.json`, with raw log SHA256 `db678339df2b863889f95749bdca7ad80cae3cec15e49eeb9816a9671cfa1d93`. No tests or full CI stages executed. Strict formatting, Markdown lint and diff checks pass; the corrected fixture still requires compilation and execution.
