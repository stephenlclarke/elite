# Original sealed dispatch

## Motivation

G01 requires a uniquely identified one-tonne sealed record, no berths or deposit, H0 and an untimed delivery. The existing native courier supports unique custody and actual receiving contacts but assumes six timed rows with a different reward schedule.

## Required behavior

Expose only native package rows 1, 3 and 5 while retaining all six saved draws. Freeze a reachable one-to-three-leg quote with reward 320 + 90 per leg CR. Actual sender confirmation issues the original item; actual quoted receiver confirmation consumes it and pays once. Back, failure and replay never pay or recreate the item. First genuine success grants the existing family clue once.

## Compatibility and scope

Reuse the existing courier saved representation, native action admissions, loss receipts, transaction publisher and Original offer policy. Only the exact G01 declaration may carry a nil deadline. Existing timed six-row providers retain their deadline, capacity and identity checks. No new clock, stock ledger, save schema or Game hooks.

## Validation and remaining risks

Focused owner qualification passed as an explicit 17-method / 25-case aggregate; one independent review is pending. The six unchanged stale legacy pinned-route cases remain a known pre-existing MAIN/release blocker, verified by Root against main CI without G01. Full application, coverage, sanitizer, leak and release gates remain with the canonical integrator. Related PR notes: [PR-original-sealed-dispatch.md](PR-original-sealed-dispatch.md).
