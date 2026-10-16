# Next mission implementation readiness

Source-only assessment, 16 October 2026, against immutable engine/Gallery integration `1e4e622da7313b4b55a47637f234d334fabbe535`. The Gallery slice is locally integrated. This assessment does not activate another mission or establish central/main integration. Mission Researcher retains research and finance-engine ownership. All implementation assignments go through Orchestrator to Mission Coder 1.

## Current checkpoint

G21 station donations and the two-phase Gallery trial repair are locally integrated at `848d7b7e8359f921aab395a6204405df47806542`, preserving all789 acceptance inputs from canonical `51cb55617a2e8dd21fddde6e67b425ee978a7bdd`. Full CI passed615 methods/692 cases in each test lane with zero leaks. The table below remains the original pre-G21 assessment; its G21 prerequisite is now closed. The next packet is the [G02 courier native design brief](MISSION-CODER-G02-DESIGN-BRIEF.md). Historical missions and the full engine remain incomplete.

## Findings

No additional historical mission assessed below can honestly be handed over as pack-only implementation on this base. Completed research is distinct from available native mechanics. In particular, the presence of schema2 dialogue, credits, cargo, NPCs or a contract board does not establish each source's custody, facility, generator or AI contract.

| Candidate and existing research | Available foundation | Precise missing prerequisite |
| --- | --- | --- |
| P30 local documents2, `rescue-courier-mission-specifications.md` | Station dialogue, native calendar, once-only terminal receipts and main-orbital contracts | Actual RRS waystation/HQ offering facility with independent main-station destination; native RRS reputation and scenario counters; protected zero-tonne document custody; source hourly/eligibility/departure rules. A same-main-station generic courier is not this mission. |
| P19 shared GSE loan, `iron-raven-finance-specifications.md` | Root-owned campaigns, exact child joins, repeatable questions, actual calendar, atomic credits, retained books and partial commodity collections | Independently retained native obligation/controller, frozen offer/settlement quotes, actual eligible station-opportunity ordering, once-only decisions and receipts after parent termination or missing content. The complete finance strand additionally needs physical sample/pylon/thermal/scoop/receiver/contact AI. |
| C07 stolen police ship, `classic-project-specifications.md` and `data/classic-project-profiles.json` | Native commander score query, source-labelled NPC fits, deterministic owned actor IDs, actual player-attributed destruction and station credits | Per-instance encounter destination and entry-relative placement. Existing `encounter.ensure` derives its location/actor points from a fixed manifest. C07 freezes acceptance galaxy, issuer, `(issuer_system+17)%256`, and placement8000 units ahead of entry. A fixed Lave patrol is not that profile. Full explicit one-missile/escape/reentry behaviour also needs verified native support. |
| G21 donation, `generated-space-project-specifications.md` and `data/generated-space-project-profiles.json` | Actual main-station board identities, frozen offers, strict native debit and durable transactions | Single atomic pledge and issuer reputation receipt; complete food donation rather than the existing partial collection minimum; native issuer/location scope frozen to the accepting station. The existing collection resource has a fixed manifest station and supports partial lots. Story flags cannot serve as reputation or transfer proof. |
| G02 generated data/package courier, same generator specification | Generated board offers, calendar deadlines, exact destination main station, protected tonne payloads and atomic settlement | Source-profile xorshift32/shortest-hop candidate generation and offer requirement checks; protected zero-tonne digital custody distinct from the physical one-tonne variant. Existing demonstration generators/LCG draws are not the researched generator. |
| C01/C02 source-faithful schema2 conversion, existing bundled Executive profile | Existing schema1 playable campaigns, classic hull damage rules and source-labelled routes | Explicit bridge for source naval stages, removal-versus-destruction semantics, wrapping combat-point reward, original scheduler/RNG/clue opportunity and migration without dual activation. These are not supplied by a generic scripted patrol. Existing schema1 playability is preserved. |

## Engine evidence

At this base, `ScriptEncounters.ensureScriptEncounter` creates an owned plan from `ScriptEncounterDefinition.galaxy/system` and fixed actor coordinates, then tests admission against that same declaration. Deterministic identity is implemented; instance-selected encounter placement is not. Actual removal events include `destroyed_by_player`, which is an available attribution fact rather than a missing feature.

`ContractStationIdentity.valid` supports `main-orbital` only. Existing board generation supplies64 native LCG draws, not the researched common xorshift32 generator. `ScriptCollectionDefinition` freezes a manifest station and `collection.deliver` transfers the available partial minimum; neither establishes an arbitrary accepting-station all-or-nothing donation. These APIs must be extended explicitly where a selected mission requires more.

`credits` rejects insufficient actual funds and overflow, and the native transaction publisher rolls back rejected proposals. That supports a strict debit. It does not establish the loan's short/zero-balance closing policy, due-opportunity ordering, independent lifetime, retained financial UI or complete source finance campaign.

The exact profiles and their provenance/fixtures remain in `/Users/sclarke/github/elite/docs/research/`. Necessary project estimates remain labelled; no missing engine mechanic is converted into an assumed historical fact or a placeholder mission.

## Original pre-G21 assignment boundary

The original next packet was G21 after a reviewed typed pledge/issuer-reputation adapter, covering all three difficulty amounts and both credit/food variants. That adapter and complete mission are now locally integrated as recorded above. G02 remains blocked on the explicit native design in its linked brief; it is not a pack-only conversion.

Mission Researcher continues the already-owned shared native finance design/implementation. The existing detailed loan research and `/Users/sclarke/github/elite/docs/STATION-FINANCE-DESIGN.md` are suitable source material for a separately bounded controller or UI task only once its engine boundary is explicitly assigned. Do not start a competing finance implementation or wire a fake UI to assumed APIs. Mission Coder's next pack should use the resulting actual reviewed primitives, with native physical/transaction/save/Gallery acceptance.

Current quiet CPU/GUI leases remain with Orchestrator's assigned validation worker. This assessment used source reads only and requests no builds, tests, native app work, release, push or PR.
