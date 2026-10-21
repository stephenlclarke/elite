# Legacy raw saves can bypass native dock authority

## Problem

The legacy Commander loader accepts newly introduced `nativeStations` and `savedContracts.rrs` fields. A structurally valid pure-ledger dock receipt can therefore enter through raw JSON, bypass the native save barrier, and receive transient docking authority during restoration. Both RRS service custody and original-main arrival custody are affected. The normal native writer already refuses those unproved receipts.

## Required behavior

Non-null native station and RRS state must use the versioned Commander/world save path. Legacy raw Commander input must reject those typed fields before decoding, preserving the current live Commander, scene and previous save files. Ordinary legacy input with absent or null station/RRS fields must still load. Authored payload keys and genuine versioned saves keep their existing behavior.

## Acceptance

Regression coverage must reject structurally valid RRS and original-main pure-ledger receipts through the actual raw loader, retain whole live Commander/world state and previous files, and verify genuine swept-entry versioned saves still restore authority with a fresh epoch. Compatibility coverage must load ordinary legacy files with absent and null optional fields.

## Validation and remaining risk

Source checks and strict Swift formatting pass. The seven authored cases have not been compiled or executed in this worker; Root owns the validation lease and must run them against the composed source, then complete `make ci`. No runtime acceptance, merge or release is claimed.

Related change: [raw native save authority repair](PR-raw-native-save-authority.md).

## Compiler follow-up

Checkpoint 180 failed during test discovery compilation: the negative main-dock fixture modified `game.commander.nativeStations` while reading `game.commander.scriptState.calendarSeconds` in the same assignment. The fixture now snapshots that actual primitive clock value immediately before the assignment, after the same Boolean dock call. Receipt data, allocation order, refusal and conservation assertions are unchanged; no production code or calendar policy changes. The failure proof is `/tmp/elite-full-review-ci-180/root-discovery-failure-180.json`, with raw log SHA256 `db678339df2b863889f95749bdca7ad80cae3cec15e49eeb9816a9671cfa1d93`. No tests or full CI stages executed. Strict formatting, Markdown lint and diff checks pass; the corrected fixture still requires compilation and execution.
