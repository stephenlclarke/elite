# test(equipment): validate stable IDs and directional grade benefits

## Changes

The generic module-definition test now requires the exact four-family registry, including hyperspace drives, and exact ordered persisted IDs per family. It retains identity family/version and uniqueness checks, energy revision two versus revision one elsewhere, nonempty display names and the original explicit shield ID list. Drive IDs remain `basic`, `intermediate`, `advanced`; no production prefix or migration policy changes.

Every grade still executes the actual 500-basis-point quote through the full progression validator. Adjacent grades retain identical required axes, cannot worsen any required axis in its declared beneficial direction, and must strictly benefit at least one. An independent assertion pins jump-spool as lower-is-better and stock drive seconds as 10/5/1. The ordinary 0.7-second floor, mass-lock policy, real upgrade effects and all legacy compatibility tests remain unchanged. Elite energy remains present as requested by FR-020.

## Scope and verification

The exact isolated parent is `25574f2e1ebfc26c52fa33700eaeac9e48db853b`. Three files change: `EquipmentModuleTemplatesTests.swift` and this issue/PR pair. Only `equipmentModuleTemplatesHaveStableMonotonicValidatedDefinitions` changes: one existing method/one case, no new tests or helpers. Every original byte outside that method, shared `moduleQuote`, other tests and production remain unchanged. All prior refs remain preserved.

Source formatting/parsing, strict lint, Markdownlint and static whole-file correspondence/assertion-effect/selection/hash checks are the only authoring validation. No compiler, typecheck, discovery, tests, build, native/UI/media, GitHub, push, merge or Sonar jobs run. Canonical source/HEAD/inputs remain frozen during live 352; this separate source leaf uses Root's explicit cold-worktree exception. Root final review and preservation of 352's terminal artifacts precede composition or rebuilding. No runtime pass or overall CI result is claimed.

Eventual PRs require completed clean `@codex review` cycles, fixes and repeat review for every actionable finding, required final-head checks and approval, and protected merge without bypass.
