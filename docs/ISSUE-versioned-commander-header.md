# Legacy raw-save checks reject legitimate versioned station headers

The new raw Commander admission guard correctly rejects station and RRS custody without a versioned retained world. However, `ScriptSaveStore.read` reused that raw-input namespace for `commander.json` even in schema 21 archives. The writer keeps native station state in that header while storing mission/contract state separately. Legitimate versioned loads therefore fail before their retained world can be validated.

## Required boundary

Select a distinct current-header preflight only inside the existing versioned archive reader. Permit its native station header state, keep misplaced mission/contract/RRS custody rejected, and retain all subsequent chunk/hash/schema/world/Commander checks. Actual raw Commander files and older archive headers keep the original strict native-field refusals. No Boolean, receipt or raw file may gain native authority through this repair.

## Acceptance

Existing genuine RRS/main doorway save/load cases must succeed with fresh epochs and full Commander/file conservation. Their current archive downgraded to schema 20 must refuse. Existing raw laundering, absent/null legacy compatibility and misplaced RRS tests remain. The failed combined runs remain historical; passing source lint does not establish runtime acceptance. See [the repair handoff](PR-versioned-commander-header.md).
