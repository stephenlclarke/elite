# Clear docking bindings only when NPCs are retained

Docking uses the same positive-count precondition already used by commander load before resetting ordinary NPC bindings. Retained craft still lose their scene-local bindings after all docking refusal checks and before the scene is discarded. Commanders without NPC custody avoid an unnecessary optional-state writeback.

The original missing-pack whole-commander and cargo assertions remain intact, alongside the actual NPC docking and restoration regressions. Source formatting passes; targeted execution and complete CI remain pending. Motivation: [issue](ISSUE-empty-npc-docking-state.md).
