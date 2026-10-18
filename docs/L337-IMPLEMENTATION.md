# L337 implementation scope

Accepted human handoff: 2026-10-18. Verified manifest SHA-256: `770243fb1596a60fc0d8151519f3bcb8ab17b04c5a9eb15c7d184fa1fd6e574d`.

This verified handoff supersedes historical private/no-handoff labels. Checked design data establishes the implementation target; runnable gameplay, release readiness and rights acceptance remain pending. The comprehensive receipt and target ledger remain in the handoff attachments. Only explicitly allowlisted content may later enter runtime.

## Approved target

- Coordinate the L337 owned-source, module, product, repository, path, packaging and Homebrew tap rename, including bundle identifier `io.xyzzy.l337`.
- Retain 171 independent ship specifications, 94 approved hulls and three textures. Use SH123 Larvaal Sovereign for branding produced by the game renderer.
- Deliver eight galaxies with 2,048 original worlds, their economy and the new Avenor commander.
- Replace superseded stories with 39 original campaigns, 21 repeatable mission families, four tutorials and 758 artwork assets. This records scope without publishing quest solutions or private artwork bundles.
- Preserve 64 distinct first-success clues and the ordered PLUGH/SH171 progression: Medusa defeat, reconstruction, then paid fabrication. XYZZY must not bypass this gate.
- Use the authoritative W / Return / E / Q bindings and the latest hold and salvage rules. Main-laser asteroid shattering must leave strictly less than 5% collectible yield; physical dust behavior remains an explicit open decision below.

## Delivered slices and remaining acceptance

Station AUTO defence is source-integrated, but the original procurement journey still fails during final approach. Both unattended freight cases have passed focused validation. Mission-folder routing is source-integrated; its runtime, CLI and native-picker acceptance are pending. The shared-controls generator and generated-byte check pass nine Python tests; native input, help and HUD wiring remain pending.

Repository/path/content renaming, playable replacement missions and overall game completion remain pending. The fresh L337 product and current save/content formats supersede predecessor-import obligations. Preserve historical releases, notices, repository protections and user working changes.

The original 12 priorities and their engine/native-gameplay acceptance requirements remain in force; see the [delivery backlog](DELIVERY-BACKLOG.md) and [mission-engine ledger](MISSION-ENGINE-COMPLETION.md). Completion still requires full `make ci`, coverage and sanitizer/leak gates, exact-commit SonarQube analysis from committed main, clean PR review and final-head GitHub checks, measured performance, renderer-generated media, current-format saves, documentation, fresh installation and release validation. The project PR review loop, including distribution tap updates, remains mandatory. Source integration or a design-data check alone closes none of these gates.

## Ownership

| Owner | Current responsibility |
| --- | --- |
| G1 | Central integration, native acceptance, validation and release |
| G2 | Bounded station-defence phase work |
| MC1 | Mission engine and content |
| MBA | Shared generator and lightweight independent work |

## Unresolved gameplay decision

Shattered Wake: the relationship between physical dust impacts and collectible asteroid yield is unresolved. The strict under-5% collectible limit is fixed; whether noncollectible dust has physical impact behavior must be confirmed before implementation. No dust behavior is selected by this record.
