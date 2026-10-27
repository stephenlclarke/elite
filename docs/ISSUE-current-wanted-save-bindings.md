# Current wanted bindings were cleared late during save

CI612 reported current-format whole-Commander equality failures in PLUGH, campaign, docked NPC and solar save boundaries. The retained two-campaign before/after artifacts establish the field-level difference: after normalizing Codable dictionary/set ordering, the wanted ledgers differ only in four current career bindings changing from present to absent. Identity, resources, legal/reward state and history match.

Docking cleared NPCPersistenceLedger bindings after capturing NPC state, but left the associated wanted-career current bindings populated after those craft left the scene. Saving later called career reconciliation and silently cleared those stale bindings. That delayed normalization changed otherwise parked current state at publication. First-save fixtures could also leave current mining policy implicit until the writer persisted it.

The separate GameplayScene legacy-default subcase removed flight allocation/time state while retaining current career records that require that timeline. Its invalid result was correct. Backward compatibility and predecessor saves are explicitly no longer required; constructing or migrating that obsolete mixed format is outside the current L337 contract.

Current save/load correctness, honest current bindings, parked resources, aliases, literal history and transaction conservation remain required. The solar comparison after relaunch is a legitimate new-scene transition: new accepted physical identities and sensor reports can change while durable career history must remain intact.
