# Hosted snapshot compiler failure

PR #19 head `f82953b920de06461a017c7aad2644ec65857410` failed hosted CI run [38927024481](https://github.com/stephenlclarke/elite/actions/runs/38927024481) before tests, during `mission-packs-check`. The sole distinct compiler diagnostic identifies the large `bodies.compactMap` actor-snapshot expression in `GameplayScene.swift:140` as exceeding type-checking time. The original failed log is preserved separately. The earlier local repair gate remains source-specific evidence, not a passing hosted result.

The correction gives the result array, catalogue performance, energy, speed, legal record and cargo explicit types before constructing the same actor snapshot. Value precedence, defaults, units and physical identities remain the same. Existing scene, NPC-resource, persistence and telemetry regressions cover these facts. No test or compiler failure is waived.
