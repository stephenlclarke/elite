# Fleet design v2 - 30 October 2026

This is the design response to Stephen's request to resolve the fleet review, consider the shared ChatGPT discussion, review naming and prepare work that several coders can implement together. The subsequent correction limits blocky autonomous design to the rogue mission AI, the Tithe Network. This request resumes this design task; it does not restart previous implementation or testing pipelines.

**Current author handoff is revision 2.2:** [the single bounded review correction batch](REVIEW-CORRECTIONS.md) follows [the Medusa loadout correction](REVISION.md). Stock, limited mission fit, paid stock purchase and actual player maximum upgrades remain separate configurations. The mission is beatable; a purchase grants no free maximum preset. The new batch changes no balance or geometry and awaits only the reviewers' own narrow finding verification.

The pack contains 171 individually specified base hulls, three Tithe conversion designs, exact numerical and naming changes, fitting and accommodation contracts, geometry requirements and disjoint implementation partitions. These are new design decisions under this request. They are not claims of prior approval, measured balance, runtime implementation, completed mesh repair or a playable release. Original frozen assets and statistics have not been changed.

## Read in this order

1. [Decisions and resolved findings](DECISIONS.md).
2. [Naming rules](NAMING.md) and [the exact rename list](NAME-CHANGES.md).
3. [Catalogue by current classification and actual use](CATALOGUE.md); each row links to its individual TOML contract.
4. [Capability, fitting and accommodation rules](CAPABILITIES.md).
5. [Geometry, detailing and physical-unit rules](GEOMETRY.md).
6. [Tithe Network ships and mission changes](TITHE.md).
7. [Shared-chat reference review](REFERENCES.md).
8. [Parallel implementation partitions](IMPLEMENTATION.md) and [acceptance criteria](ACCEPTANCE.md).

The exact handoff field meanings are in [SCHEMA.md](SCHEMA.md). The crew-service prerequisite is specified in [CREW.md](CREW.md). [PARTITIONS.json](PARTITIONS.json) lists every base ID under exactly one proposed family owner.

[EQUIPMENT-MAPPING.md](EQUIPMENT-MAPPING.md) makes the proposal/native fitting boundary explicit. The kit validator is design arithmetic, not proof of current engine costs, sockets, mass or power. [REVIEW-CORRECTIONS.md](REVIEW-CORRECTIONS.md) records the single bounded author correction batch and its preservation limits.

## Sources and precedence

Latest explicit human instructions take precedence. The mission researcher's [30 October salvage/EMP change](SALVAGE-ALIGNMENT.md) controls acquisition and Medusa; earlier kill-to-acquire wording is superseded. This v2 proposal supersedes the older original numerical candidates, E01 accommodation estimates and naming entries only for the changes explicitly recorded here. The accepted original silhouette, palettes, textured detailing, Larvaal smoothness, Medusa topology/angles and the remaining discovery/story gates remain constraints. Any subsequently verified active per-hull physical calibration wins over a new estimated target in this pack.

The original input is the exact 171-ID join in `fleet-completion-20261019/delivery-index.json`, paired with `fleet-specs/SHnnn.toml`. Input fingerprints are in [provenance.json](provenance.json); every record retains its source fingerprints. [changes.json](changes.json) contains the complete before/after performance and access values. It is not a second progress ledger.

The current authoritative completion ledger remains owned by the orchestrator. [IMPLEMENTATION.md](IMPLEMENTATION.md) defines proposed ownership boundaries and dependencies, not active assignments or a competing status register. Root must record actual owners and bounded source paths in that ledger before dispatch. No native build, renderer, integration test, quality run, process cancellation, release or merge is authorised merely by this document.

## Maintained and generated files

`authoring.py` maintains explicit per-ID numerical rows, naming decisions and generation rules. `ships/SH001.toml` through `ships/SH171.toml` are the generated, self-contained design contracts for coders. Three conversion TOMLs and simple top-view assembly diagrams live in `ai/`. The diagrams are code-native box-assembly briefs, not game portraits, final mesh geometry or renderer acceptance evidence.

To change this proposal, edit the maintained decisions in `authoring.py` and the relevant narrative contract first. Run the script with `--source-workspace` pointing to the frozen original proposal, then run `--check`. Do not hand-edit generated copies or edit the frozen input. This authoring workflow is separate from the eventual runtime TOML loader and renderer media pipeline.

Actual runtime ships must ultimately load their complete specification and design from the maintained per-ship folder. Runtime catalogue tables, showroom, flight, NPCs, missions and saved ownership must share that identity. Generated Swift and media are derivatives, never a second stat authority.

## Deliberate scope

The pack resolves the review at design level. Coders still need to implement the contracts, repair meshes, demonstrate real equipment effects and qualify the resulting game. In particular, an individual geometry target is not a measured docking clearance, and a recommended rescue or survey kit is not automatically installed equipment.
