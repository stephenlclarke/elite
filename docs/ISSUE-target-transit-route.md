# Issue 18 child: disclose retained NPC transit routes

Refs #18. The target panel reads ordinary cargo and route provenance from the physical NPC. Generated manifests and scooped cargo already reach that projection, and unavailable legacy manifests correctly remain unknown. Scripted NPC transit has a separate typed route ledger: its spool, opening and arrival records retain the actual endpoints and actor bindings. The panel ignores that route and can show both endpoints as the inferred local system even when a bound transit route exists.

Join only a unique current mission/native actor route in a supported phase, rejoin its endpoints to the live original-world catalogue, and use it only when the NPC endpoints are absent or inferred local. Preserve explicit recorded/generated NPC routes, current cargo, resource readings and existing Pirate/Military disclosure gates. No simulation, save, navigation plan or discovery changes are needed.

This is a bounded projection correction. Missing legacy cargo producers remain missing; no manifest is reconstructed from hull, role or mission labels. Full issue 18 resource tracking, persistence, integration and delivery acceptance remain open.
