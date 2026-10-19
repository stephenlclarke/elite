# Salvage acquisition fixture assumes an idle trigger must be suspended

CI 612 at `f939e94d263c07afc936af1599b19685094600a5` recorded `NativePagedSalvageFixture.swift:251` while `refusedNativePlacementDiscardsPrivateOfferAndPreservesEveryReleasedLot` prepared its shared genuine release. The issue state has an idle trigger, no pending press/activity, successful salvage hold acquisition and `workFireSuspended == false`. Earlier target/actor/guidance/section requirements had completed; placement-refusal assertions had not yet run.

Approved control change `b20e6cf0` deliberately suspends only an already-held trigger during interruption. Idle Tab selection must not invent a stop; existing interruption stops must survive. The fixture's unconditional suspended-fire requirement predates that contract. Correct the oracle using the actual pre-Tab held/suspended state, preserving every real acquisition, readiness, fresh-press, cutting, custody and publication check.

[Fixture-only correction](PR-salvage-engagement-oracle.md).
