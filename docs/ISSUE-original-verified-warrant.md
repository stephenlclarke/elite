# Original verified hostile warrant

## Motivation

G06 requires an actual player-attributed destruction record for a unique armed aggressor and a real report to Voss. Generic encounter destruction alone also includes non-player kills and cannot establish this qualification. A narrative counter cannot replace the native actor record.

## Required behavior

The frozen Avenor-Renas-Avenor route has two legs and H0, paying 1120 CR only after the exact target dies to the player and Voss receives its report at the issuing main station. Cargo, berths and deposit are zero; there is no deadline. Wrong, clean, culled or non-player targets never qualify. Failure and withdrawal pay zero. A repeat creates a new native offer, instance and actor while retaining the first family clue.

## Implementation boundary

Reuse existing native NPC weapons, actor admission/destruction, contract jobs, station choices, settlement and completion receipts. Exact G06 acceptance and terminal guards consume these records. A closed completion predicate also protects retained success and attribution on current-format reload without requiring the player to stay at the issuer. No new state, schema, producer, receipt type or Game hook.

## Validation and remaining risks

Matching MBA build, native pack CLI and focused owner qualification passed as an explicit 16-method / 22-case aggregate. One independent review is pending. Full application, coverage, sanitizer, leak and release gates remain with the canonical integrator. Related notes: [PR-original-verified-warrant.md](PR-original-verified-warrant.md).
