# C07 stolen police ship: next design readiness

Candidate for the next mission design review after G02 courier acceptance. This is a research/dependency audit, not an implementation assignment or an assertion that the historical mission is replicated. The retained identity is C07, profile `PROJECT-PCPLUS-C07-v1`; it is not a new duplicate mission.

## Historical evidence refreshed on 16 October 2026

The existing S09 [Elite Plus play guide](https://www.tales-from-darkenedroom.com/post/elite-plus-missions-galaxy-9) describes a cash-paying hunt for a stolen military police craft in a named system. Its general mission notes say docking presents missions and combat rating does not drive their progression. It gives no exact C07 hull statistics, cash amount, spawn coordinates, escape reconstruction or non-player-kill rule. Its linked mission screenshot could not be read through the research tool; no screenshot text or binary predicate is claimed recovered.

The S08 [historical FAQ](https://wiki.alioth.net/index.php/AFE_FAQ3) lists the mission and reports a hyperspace-count trigger basis after leaving the initial galaxy. It supplies no exact count. This is community reporting, not executable verification. It does not establish the project score128 gate.

A [1998 alt.fan.elite discussion](https://groups.google.com/g/alt.fan.elite/c/zjW8mFI_eeA), especially Martin's29 April list and a30 April player's recollection, independently corroborates the mission's presence. It does not establish numerical parameters, completion/respawn mechanics or a definitive campaign order. Inventory-list order must not be treated as a recovered scheduler.

## Retained project specification

The source-labelled profile remains `/Users/sclarke/github/elite/docs/research/data/classic-project-profiles.json`; supporting narrative is `/Users/sclarke/github/elite/docs/research/classic-project-specifications.md`. Its score128 gate, any-main-station offer, acceptance galaxy, `(issuer_system + 17) % 256` target system, initial8000-unit entry-forward placement, SH136 Viper surrogate/pulse laser/one missile,6,000 CR payment and issuer hand-in are explicitly project estimates or choices. Neither Oolite's model nor the common player refit proves the original Elite Plus target's fit. Preserve those labels and source IDs.

Freeze actual issuer, galaxy, target system and unique target identity at acceptance. Only actual player-attributed destruction of that target may advance the hunt; innocent police and narrative flags never qualify. Payment is once at the actual issuer station. No historical deadline is established. Reentry must preserve target identity and already consumed resources. Any new behaviour requires a versioned, clearly labelled project rule.

## Native prerequisite and remaining policy gaps

| Boundary | Actual issue to settle before coding |
| --- | --- |
| Instance-bound encounter | Current encounter declarations use fixed galaxy/system/coordinates. Add an immutable native binding for this acceptance's derived destination and entry-relative initial placement; do not substitute a fixed Lave patrol. |
| Combat fit | Verify the actual source-labelled NPC Viper model, durability, pulse weapon and single consumable missile through existing native readers and firing paths. Do not assume a fitted missile proves launch/consumption support. |
| Escape and reinstatement | Specify which genuine native departure/escape facts count, when a living target is restored, and its retained energy, equipment, missiles and position. Distinguish unloaded/cull state, escape and destruction. Exact original behaviour remains unverified. |
| Non-player destruction | The current profile requires player attribution but does not define the otherwise destroyed unique target's terminal outcome. Recommended additional project policy: native terminal failure, zero mission payment. Its cause/proof and future offer eligibility need explicit design review/versioning. |
| Campaign eligibility | Historical count and full PC-PLUS scheduler are unresolved. Keep128 visibly a project gate. State whether this optional adaptation can be offered again after success/refusal/failure; once-only payment alone does not answer that question. |
| Completion and Gallery | Use actual destruction/terminal/shared receipts, issuer proof, private publication/rollback and saved content identity. Provide an actual fly/fight/report trial with retained live-state isolation. No synthetic death, free missile refill or surrogate-as-historical claim. |

The next handoff should freeze a selected profile snapshot, settle these policies and propose the smallest reusable instance-bound encounter/escape interface before implementation. This audit changes no existing research profile or mission inventory. Frontier/on-foot exclusions and station substitutions remain controlling.
