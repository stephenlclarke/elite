# test: make showroom ownership and compatible trade fixtures explicit

The existing private showroom helper accepts an optional owned hull, default nil. Only the Cobra-specific profile and named owned-Cobra filter scenarios opt in to SH023, with valid initial stock fuel, energy and shields before equipment ownership or UI entry. All other helper callers retain the current Peregrine. Exact catalogue identities, source/provenance facts, profile numbers, filters and labels remain.

The generic pin/reset check uses the actual commander ship ID and requires the current-baseline flag. Assembly browsing captures the whole actual commander and requires full equality after rendering, strengthening the old JAMESON name-only assumption without changing app defaults.

The primary confirmation flow uses a compatible Cobra70-to-Boa70 initial setup. It retains the same selected Boa, all four internal viewport loops, click/keyboard navigation, cancellation, confirmation, labels and ownership assertions. It requires the real quote to be allowed before opening review and checks resulting cash against that frozen quote. The blocked-trade control remains byte-exact, using the fresh Peregrine and its real refusal. The unrelated secret Cobra-restore test also remains byte-exact.

Source prerequisite review covers supported mounts, three carried missiles versus four target pylons, empty cargo, fuel capacity, portable initial fit, sufficient original funds and actual quote/price semantics. No production UI, catalogue, policy, price, row identity or app default changes are included.

Validation: patch whitespace and source review checked. Build/test/probe are UNRUN under Root's owner execution restriction. The finite first wave is six methods/cases: pin/reset, native profile provenance, source assemblies, owned-Cobra filtering, primary trade and unchanged blocked-trade control. Width and assembly loops are internal iterations, not extra Swift Testing cases. The helper reach inventory carries no previous PASS retention for changed callers. Focused validation, distinct coherent review, final CI and PR review/checks remain open; no playable release claim.
