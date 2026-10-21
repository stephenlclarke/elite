# test(fixtures): use current equipment saves and fitted jump policy

## Changes

The jump test independently requires the owned Advanced drive, its actual Advanced component grade and one-second statistic, the owned Military navigation device and its multiplier of one, and the resulting one-second timed policy. It then expects a one-second actual countdown. Existing out-of-range and empty-fuel refusal, finite fuel 350/debit, actual arrival, strict schema-26 save/read and whole restored Commander with the existing explicit station-rebind expectation remain unchanged.

The shared native equipment fixture retains the entire supplied valid version-three Commander in a fresh docked game. Its system list, selected system, market and full native energy/shields reproduce the former raw loader's intended initial scene. It uses actual `GameRuntime.save`, requires commander-scope schema 26 and strictly reads the published chunks. Its independent expected Commander starts from the original supplied value and applies only prepare/mirror, current mining-policy persistence and a new-Commander calendar if absent. It never takes expected state from a runtime snapshot.

Whole published and loaded Commander equality remains, with explicit original owner/hull, complete inventory/components/provenance, purchase history, salvage source ledger, cash/cargo/name/hull/fuel/missiles, contracts, accommodation and legacy/script mission conservation. Initial docked/body/system/market/resource checks protect the scene construction. The actual delegate loop is stopped before its real load, preserving the original native input route and UI lifecycle.

`originalSave` now contains the actual versioned pointer. The fixture also retains every original generation file and requires exact file-tree equality after load, initial painting and existing read-only verification. `nativeEquipmentBytes` remains the semantic Commander JSON helper. Existing painted purchase, resize, stale/duplicate input, recovered source consumption exactly once, component/device identity, no new paid receipt or cash, focus, private preferences, pixel/scale and window assertions remain unchanged in all eight caller bodies. Failure cleanup covers bootstrap errors as well as delegate loading.

## Scope and verification

The exact parent is `a74e6056fee8e24888d261b0415711814236a3d0`. Four files change: `EliteTests.swift`, `NativeEquipmentViewTests.swift` and this issue/PR pair. Nine existing methods/nine expanded cases are affected by one jump assertion context and the shared bootstrap/read-only helper. No new test method or production/G1 EMP change. All eight fixture caller bodies and other source regions remain byte-identical. The nine earlier frozen refs, including the parent, are preserved; completed historical and current save constructions remain intact.

Source formatting/parsing, strict lint, Markdownlint, assertion-effect inspection and exact scope/selection/hash checks are the only local verification. No compiler, typecheck, discovery, test, build, UI, media, GitHub, push, merge or Sonar job runs. Root must review the committed source before G1 validates it. Validation 339 remains failed overall; no execution success is inferred from these source checks.

Eventual PRs require completed clean `@codex review` cycles, repairs and repeat review for every actionable finding, passing required checks on the final head, required independent approval and protected merge without bypass.
