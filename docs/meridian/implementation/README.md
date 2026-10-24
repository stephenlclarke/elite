# Finished-game implementation guide

This folder accompanies the [finished-game oracle](../README.md). It keeps the design, implementation inputs, audit and a frozen ledger together so a session can understand a mission without depending on another chat's memory.

## Work authority

The [ledger copy](COMPLETION-LEDGER.snapshot.md) is an unedited, dated snapshot, not an editable work queue. [Its receipt](LEDGER-SNAPSHOT.json) records the exact published source commit, capture time and SHA256. The [live main ledger](https://github.com/stephenlclarke/elite/blob/docs/developer-reviewer-workflow/docs/COMPLETION-LEDGER.md) remains the single source of truth for packet identity, ownership, dependencies, gates and progress. Read its current version before starting work. Do not dispatch work, mark delivery or create a second queue in this snapshot.

Latest scope remains research/design/documentation here. The human's M01 boundary stops other project sessions after verified M01 delivery; Mission Researcher alone retains its already authorised scope. These documents do not restart stopped workers or authorise code/native/PR/release work.

## Inputs needed for each mission

1. Read [the gameplay description](../missions/GAMEPLAY.md) and [controlling physical/recovery specification](../missions/gameplay/GAMEPLAY-SPECIFICATION.md), including resource/custody, clock, failure and gallery rules.
2. Read the campaign's C01-C39 reading view and complete [canonical JSON](../missions/definitions/), including every stage, target, choice, branch, loan, fee and clue. Families, tutorials and Wayfarer services have their own complete definitions there. The finale has the exact 64-source register and seven ordered transitions.
3. Join any C09-C39 [physical profile](../missions/gameplay/campaign-profiles.json) and all sources' [follow-up profile](../missions/gameplay/recovery-policy.json). These are new explicit design estimates requiring native integration and balancing, not claims about completed gameplay.
4. Read the relevant later [UX closed operation contracts](../missions/gameplay/contracts/ux/) and [original authoring sources](../missions/authoring/). Later explicit resolutions take precedence over frozen earlier contracts. The [source manifest](../references/CONSOLIDATED-SOURCES.json) records provenance and each copy's scope.
5. Resolve real hull, equipment, world, stock and people prerequisites against [canonical gameplay data](../missions/gameplay/), the [ship reference](../SHIP-REFERENCE.md) and [artwork manifest](../assets/missions/manifest.json). Use source-scoped receipts, not matching labels.
6. Check [the mechanics audit](../GAME-MECHANICS-SUPPORT.md), [objective matrix](../MECHANICS-OBJECTIVE-MATRIX.json) and [coherence review](../MISSION-COHERENCE-REVIEW.md). A candidate source path, validated design graph, rendered illustration and playable release are different evidence.
7. Use the live ledger's authorised packet and boundary. Record native acceptance evidence there through its owner when implementation is actually assigned; preserve actual branch/loss/receipt tests and exact head attribution.

## Runtime architecture references

[The scriptable engine design](../missions/gameplay/contracts/engine/SCRIPTABLE-MISSION-ENGINE-DESIGN.md) records typed events, actor transactions, domains, unique instances and saved progress. It contains historical adapter examples; those identities do not add retired missions to the finished original game. [Candidate pack-format documentation](../missions/gameplay/contracts/runtime/MISSION-PACKS.md) describes a bounded supported schema, not automatic support for every authoring field. Implement missing primitives through GameRuntime-owned producers, with AppKit UI on the main actor, before translating a mission to the runtime schema. An arbitrary script-emitted success event is not proof of a physical operation.

## Reading map and coverage

The bundle contains 39 campaigns/368 stages, 25 families/75 stages, 64 distinct required clue sources, seven finale steps and 171 new fleet records. The original objective matrix has 450 rows and 78 explicit branch variants. The recovery policy defines two five-step alternatives per source: funded renewal/remedy and guaranteed continuity inquiry, 640 additional design objective rows. Their specification does not enlarge existing native coverage. The manifest keeps all 758 mission graphics and 171 geometry reference images under the same root.

All current canonical mission data and gameplay specifications live below `docs/meridian/missions/`. Root Markdown files provide the full reading oracle, artwork/ship appendices and audits. Update the canonical data, affected reading views and validation/provenance together. Do not substitute historical research, old main ship images or a prior implementation backlog for the final-game target.

[Document update and validation rules](UPDATE-GUIDE.md) describe how to keep all definitions, reading views, provenance and the ledger snapshot consistent.
