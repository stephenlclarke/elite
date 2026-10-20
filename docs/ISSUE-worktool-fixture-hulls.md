# Controlled work-tool fixtures need a supported hull

Run 955 on `ff52dae618c16db1652eb75f33ffe33b135dce11` records unsupported-slot setup failures in cutter and native paged salvage tests, and a missing fitted mining work tool in MiningWorkToolTests. The cutter fixtures grant a cutter to the fresh SH025, which has no declared work tools. The mining maximal-hardware initializer correctly leaves unsupported utility tools unfitted, then the fixture requires one. Production capability guards are correct.

Root assigns MC1 the three setup helpers in SalvageCutterRuntimeTests.swift, NativePagedSalvageFixture.swift and MiningWorkToolTests.swift, based on `34cedf63de90677a7d61701e0796dd54776c8eb3` with observed 955 file bytes unchanged. Explicitly select actual SH023 with both work tools before fitting or native launch, and initialize its legitimate fuel/resource pools. Preserve grants, physical scenes, budgets and every existing assertion.

The shared native fixture has ten acknowledged consumer files. This bounded change has no retained PASS claim for those consumers. First-wave validation is nine methods/cases through G1; source-only implementation is UNRUN and awaits focused validation and independent review. G1 owns the canonical ledger and integration. No app default, production rule or other 955 failure family is in scope.
