# Ship the approved G02 courier pack through default discovery

The approved `project.generated-couriers@1.0.0` pack already uses the actual native G02 engine, but its manifest and Lua lived only in documentation. Production startup loaded schema-1 missions without discovering schema-2 script packs. Players therefore could not reach the courier provider through a normal packaged installation.

## Production path

Package the exact approved manifest and Lua under `Sources/EliteCore/Resources/ScriptPacks/generated-couriers`, using one SwiftPM `.copy("Resources/ScriptPacks")` entry. The [frozen research authority](mission-specifications/g02-research-authority.json) is restored unchanged from the accepted courier packet. The current selected research profile and the frozen source/narrative hashes still match. This shipment adds no campaign or generator policy.

| Content | SHA256 |
| --- | --- |
| Manifest | f4c2a1bb538f257a229cce4911c81c4471a0aa92b2d30fe1605959c0740407f6 |
| Lua entry | 7134b0c5633be2c742d9bcc3dc9768d1966dade002685060a6db3794b18de046 |
| Frozen authority | 1b07c1423c8b2f7357358f4f5ebc815d3f605ac8edb0b728aafa04f2074b897c |
| Existing pack digest | 65ff79fef1171fa0c0af8808754c075e93c0302a33fb3e0b04fa59f59585b369 |

`GameRuntime.loadDefaultScriptPacks(directory:)` uses the existing validated pack reader and installed-library scan. Its default user directory is `~/.xyzzy/elite/script-packs`. It retains external ordering and every distinct installed version/content digest, appending the shipped pack only when that exact digest is absent. It does not overwrite files, install a hidden user copy, choose a version winner, migrate accepted jobs, generate boards or accept contracts. Missing user folders are normal first use and produce no directory writes or startup errors. Malformed or unreadable content remains reported. The bundled reader also reports missing or invalid packaged content.

The explicit `loadScriptPacks(directory:)` API retains its external-only behavior. Both paths share the same state replacement, unavailable-content suspension and error notification. Saved instances continue resolving their exact definition/version/digest through the existing resolver; changed same-version user content cannot substitute for the original saved G02 pack. No new conflict arbitration is introduced.

The central integrator owns the AppKit startup call after `loadMissionPacks()` and before `restoreStartup(from:)`: call `loadDefaultScriptPacks()` and combine its returned errors with the existing mission-pack startup alert. No Game initializer or simulation-owner hook changes belong to this packet. Without a bound writer, the existing durable-command availability gate remains; isolated Gallery trials retain their own writer and namespace.

## Content and validation limits

The pack still offers encrypted data or a one-tonne sealed package at three difficulties. It retains the actual native frozen routes, saved consignment identity, inclusive deadline, named orbital contact and once-only reward behavior. Numerical generation/reward/duration choices remain visibly labelled project estimates. There is no recovered server distribution, new RRS station service, Frontier content or ground simulation claim.

Seven authored regression methods declare eight cases: exact resource/document bytes and digest; read-only default discovery versus explicit external-only loading; identical-content deduplication; same-version and different-version content retention; malformed external error reporting; actual Contracts generation and isolated Gallery return; and saved original consignment restoration beside changed same-version installed content. The tests do not read or modify the real user pack directory or commander save.

This packet is **source-only, uncompiled and unexecuted**. Static file/hash checks, independent reconstruction of existing ScriptWire digest framing, Python JSON/TOML parsing, strict Swift formatting and whitespace checks are the available evidence. They do not prove Swift resource packaging, Lua validation, native Contracts/Gallery execution or runtime save behavior. Earlier G02 validation belongs to its historical source and does not establish that the current central composition passes.

The owned pure-adapter checkout lacked `ScriptRuntime.swift`; its exact unchanged canonical baseline was imported separately before this feature diff. Integrate only the feature commit or its exact central patch, excluding that baseline import and all unrelated owned history. Focused native validation, actual packaged startup/discovery, full `make ci`, required renderer refresh, final-head `@codex review` iterations and merge remain central integration work under the assigned validation lease.
