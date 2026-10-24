# Classic naval tests need an explicit controlled baseline

Observed CI955 naval failures compare current Peregrine resources and new starting cash against classic Cobra arithmetic and a 1000-unit balance. The source mission actions still award 50000 wrapped cash and 256 wrapped combat points for Constrictor debriefing; plan delivery awards 256 points and equipment without cash. Legacy missile damage and energy recharge behavior also remain consistent with the original assertions on a Cobra. No production reward or combat defect is established.

Root assigns MC1 only NavalMissionTests.swift and these paired notes, isolated from committed recovery source `66874c6bd73c3cdebfe684941a42d1dd130e9960`. Explicitly construct the intended actual SH023, stock pools/fuel and cash1000 in the shared naval fixture. Retain the real dock context for the paid energy-unit check, requiring actual availability instead of changing to an insufficient-technology world after docking.

All original bounty, kill-threshold, wrapping, identity, save and once-only assertions remain. Source is frozen for G1 qualification and one independent review; owner build/test/probe is prohibited. Eight finite methods/cases are selected, with no prior PASS retained for shared-helper consumers and no whole-file or release-completion claim. G1 owns the canonical ledger and integration.
