# Native station entry coverage crash

[Issue 88](https://github.com/stephenlclarke/elite/issues/88) records the retained coverage crash from run 39766540311. The captured image and dSYM match. Offline symbolication places the fault in generated Basis3 equality below the complete SpaceBody comparison in native main-station entry clearance. Compilation passed, but no completed coverage result or later sanitizer/leak gate was reached. The captured stack is consistent with exhaustion; a stack-guard exception was not retained.

Both native entry paths construct an Optional body snapshot and compare the entire value while retaining docking guidance state. Replace these temporary whole-body comparisons with a bounded borrowed comparison. Keep unique current-body membership, all stored body fields and every subsequent native source, geometry, aperture and corridor check. Do not change simulation, saves, actor isolation or entry authority.

See [the repair](PR-station-entry-value-lifetimes.md). Runtime qualification remains pending the actual hosted unit result and the release quality checkpoint.
