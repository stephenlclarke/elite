# Schema 2 mission authors lack a public format guide

[MISSION-PACKS.md](MISSION-PACKS.md) describes schema 1 single-file TOML missions. Its unqualified title and no-scripting/repeatable-contract limitations can be mistaken for limits of the whole app, which also loads schema 2 Lua folder packs and the bundled generated courier provider.

## Required behavior

Identify the existing guide as legacy schema 1 and link a separate schema 2 authoring guide. Explain the exact current loader contract, complete repository examples, sandbox, command validation, repeatable boards, clocks, choices, campaign ownership and saved content identities. Distinguish actual bundled content from examples and research references.

The current native install picker and validation option still serve schema 1 only. Document schema 2 folder discovery rather than inventing a folder picker, validator or unsupported RRS world support. README linkage belongs to G1; this change supplies the target without editing README or CONTROLS.

## Acceptance and compatibility

Markdown lint, relative links against the composed source tree, bounded TOML parsing and source/declaration checks must pass. This is documentation only, with no runtime, save-format or capability changes. Existing fixture validation and project CI remain separate gates. See [the matching implementation handoff](PR-schema2-authoring-guide.md).
