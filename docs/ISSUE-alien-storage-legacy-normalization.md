# Preserve original salvage evidence during alien-storage migration

## Problem and motivation

The ordinary salvage ledger retains deterministic plans, emitted allocator progress, current pending and stored lots, and committed technology settlements. Commodity collection and fragment destruction can remove pending custody without retaining a terminal receipt. Absence therefore cannot establish collection versus destruction, historical cargo changes or a historical collection time. Native world records require known inspection and issuance times and cannot honestly represent those missing facts.

The old planned cutter also clears saved partial work and damage membership after every release batch of at most eight items, including batches that leave the plan incomplete. An issued cursor cannot prove a completed current work budget. Planned mining damage is reflected in discarded technology; that path does not necessarily insert the separate damage-membership marker. Both original facts must survive independently.

## Required behavior

- Import the exact original section plan, seed, allocator, optional saved partial work, damage membership, depletion and distinct section/wreck destruction facts. Record only the genuine current import time; preserve the original ledger-wide operation cursor as provenance, not a dated section event.
- Give every actual original emitted identity exactly one immutable claim: actual pending, actual stored reserved migration, retained ordinary stored technology, known original settlement or unavailable with unknown cause. Discarded technology has no emitted serial and grants no source.
- Migrate actual reserved stored property through explicit current migration operations. Retain ordinary stored technology in old custody. No import claim grants credits, cargo, cutting work or a second property.
- Normalize each original settlement into one metadata record and one ordered record per original item. Share these records across affected imported sections and preserve the complete original proposal, including items in other sections, through exact joins.
- Preserve import evidence permanently. Later movement, collection and ordinary consumption use separate linked current records; they never rewrite the historical import classification or resurrect terminal claims.
- Reject contradictory, duplicate, missing, foreign and unjoined evidence. Failed checks do not mutate their input values.

## Scope and ownership

This issue supplies seven new files: pure schema, pure validation, focused test source and paired documentation. G1 owns the shared original allocator proof, private ledger export/seals, existing world and command schemas, index/codec/replay, runtime and Commander mutations, current continuation records and atomic V27 publication. Pure evidence and migration views confer no native authority.

## Acceptance and remaining work

Authored regressions cover actual old producer/collector/settlement values, unknown terminal outcomes, structural and commodity chunk identities, partial work, old batch resets, mining damage distinctions, reserved versus ordinary stored custody, a 128-item settlement spanning multiple sections, immutable history and rejection of contradictory joins. The isolated source handoff is limited to formatting/parser, Markdown lint and source audits. Compilation, test execution, supported-record page encoding, actual native migration and `make ci` remain G1-owned integration checks.

Related implementation details are in [PR-alien-storage-legacy-normalization.md](PR-alien-storage-legacy-normalization.md). No GitHub issue or PR number has been assigned.

Run 307 stopped during test compilation because the offer fixture supplied `SpawnIdentity` arguments in the wrong declaration order; zero of the 51 selected methods ran. The narrow child correction preserves all fixture values, tests and assertions. It remains unexecuted pending G1's rerun.
