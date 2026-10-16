# Preserve absent salvage state during a no-op capture

Docking and saving call `persistSalvagePoses` even when the scene has no salvage. The getter supplies an empty ledger for an absent saved record, but the capture unconditionally publishes that default. This changes the Commander despite there being no salvage work or motion to persist. The central 021 gate exposed the mutation in mission suspension and save comparisons; the independent actor purchase validation also exposed whole-Commander changes around native save/load input.

Publish the staged ledger only when its semantic value changed. Preserve every live pose, identity, health and custody check and every refusal. An explicitly stored empty ledger must also remain present. Actual changed wreck motion must still publish, and capturing that same motion again must be idempotent.

Acceptance requires absent-state preservation through direct capture, docking and a real save, plus changed motion from a genuinely generated wreck. Existing invalid pose and departure refusal tests remain required. See the [implementation handoff](PR-salvage-pose-no-op.md).
