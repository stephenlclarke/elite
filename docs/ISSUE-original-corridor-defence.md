# Original registered corridor defence

## Motivation

G07 requires three distinct registered armed raiders to be destroyed by the player, followed by an actual report to Voss. A generic destruction count also includes other attackers and cannot establish player attribution.

## Required behavior

Avenor G01S007 main orbital / Voss issues the untimed Avenor-Renas G01S185-Avenor route. L2 H0 pays 1400 CR only after all three admitted native actors have actual player-attributed destruction records and Voss receives the return report. Cargo, berths and deposit are zero. EMP disable, removal, duplicate, unrelated and non-player events do not qualify. Withdrawal and non-player loss pay zero.

Native retained actor records supply the journal's verified 0/3 through 3/3 progress. Revisit and reload preserve the cohort and cannot resurrect destroyed actors. Repeats admit three new identities and retain the first family clue.

## Implementation boundary

Reuse native profiled NPC weapons, contract jobs, actor records, station choices, settlements and historical completion receipts. Exact G07 acceptance, settlement and historical predicates plus a G07 journal presentation branch consume these facts. No new saved fields, producers, schemas or receipt types.

## Validation

Matching source build and native pack CLI passed. Focused owner qualification passed as an explicit aggregate of 15 methods / 16 cases (10 unchanged passes retained from the initial run, five corrected combat-fixture journeys passed on the final source). One independent review is pending. Full application, coverage, sanitizer, leak and release gates remain with the canonical integrator. See [PR-original-corridor-defence.md](../PR-original-corridor-defence.md).

Focused coverage from the retained final five-method profile is 120/151 helper lines (79.47%). It excludes the ten retained passing methods, including failure and withdrawal paths, whose initial profile was replaced by SwiftPM. This is a recorded coverage exception to the 90% aim; canonical combined coverage remains a follow-up gate, and no aggregate coverage percentage is claimed.
