# Docking materializes an absent NPC ledger

Resetting bindings through the optional NPC-ledger accessor writes back an empty ledger even when no NPCs have ever been retained. The existing missing-pack regression requires docking to preserve the complete commander and its carried mission cargo.

Reset actual retained bindings before discarding the scene, while leaving an absent empty ledger absent. Verify both the whole-commander no-op case and real retained NPC docking and save/load. See [implementation](PR-empty-npc-docking-state.md).
