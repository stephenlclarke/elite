# docs(missions): document schema 2 Lua pack authoring

The public mission-pack guide previously appeared to describe every pack while covering only legacy schema 1. [SCRIPT-MISSION-PACKS.md](SCRIPT-MISSION-PACKS.md) now documents schema 2 folder packs using the actual loader, sandbox, native command paths and complete examples. [MISSION-PACKS.md](MISSION-PACKS.md) is explicitly scoped to legacy schema 1 and links the new guide. See [the documentation issue](ISSUE-schema2-authoring-guide.md).

## Behavior documented

The guide covers exact schema/API/engine values, installation by folder discovery, scoped Lua handlers and atomic native publication, declared capabilities, repeatable offers and clock policies, confirmed answers versus exclusive branches, verified receipts and owned children, isolated Gallery trials, saved content pins and bounded resources. It distinguishes the one bundled generated courier provider from authoring examples. It explicitly retains the existing schema 1 scope of the native install picker and validation command, and makes no researched RRS delivery claim.

## Validation and limits

Markdown lint, bounded example/header parsing, source/capability assertions and relative-link checks against the composed repository pass. The isolated checkout predates some example files, so links are checked against their tracked composed counterparts without importing or editing them. No build, game execution, full CI, sanitizer, leak, media or Sonar run is claimed for this documentation change.

No public API, pack bytes, save format or runtime behavior changes. The documentation describes existing behavior and does not add a schema 2 installer/validator interface. G1 owns the desired README link, `[Schema 2 Lua mission authoring](docs/SCRIPT-MISSION-PACKS.md)`, publication, completed clean `@codex review`, final-head checks and protected merge.
