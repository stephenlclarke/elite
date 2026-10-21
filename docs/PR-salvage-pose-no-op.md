# Avoid publishing unchanged salvage pose state

`persistSalvagePoses` retains its existing staged validation and publishes only when the staged ledger differs from the current semantic ledger. No-op capture preserves both absent storage and explicitly empty storage. Changed valid motion still uses the same ledger publication path; invalid snapshots retain the existing refusal behavior.

Two regression methods cover direct no-op capture, docking, a real actor save, explicitly empty state, and a changed pose, velocity, angular velocity and health on a genuinely generated wreck. Repeating the valid capture preserves the full Commander. Existing invalid snapshot and actual world persistence tests are unchanged.

This is a source-only checkpoint. Strict Swift formatting, Markdown lint and whitespace checks pass; no build or test was run because the shared validation lease belongs to the isolated actor purchase candidate. Focused execution, required renderer regeneration and the complete integrated quality gate remain pending. The original 021 and actor focused failures remain preserved and are not reclassified as passes. Motivation: [issue handoff](ISSUE-salvage-pose-no-op.md).
