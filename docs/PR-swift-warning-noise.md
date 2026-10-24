# Explicit Swift warning expressions

M01.P02.I26-I31 addresses reported compiler warning noise with eight expression changes across seven Swift files: parenthesize the two salvage guard map arguments, explicitly discard three optional equipment-removal results, discard one unused fixture context, spell the intentional throwing failure as `Bool(false)`, and split clock JSON encoding/decoding into explicit throwing steps. All existing test oracles and runtime behavior are preserved.

Refs #26, #27, #28, #29, #30, #31. [Issue evidence and the unresolved #27 disposition](ISSUE-26-31.md) explain why both optional requirements remain unchanged. The #31 edit retains both `try` operations; diagnostic removal remains tentative until GitHub compiles the affected source.

Validation: Swift 6 parse-only syntax check, strict `swift-format` lint, `git diff --check`, Markdown lint and a bounded inverse-source check pass. No local build or test, integration journey, broad CI campaign or new syntax-mirroring test was run or added. The existing GitHub isolated-unit workflow compiles and executes its maintained selection on push; MBA independently verifies its actual head, results and warning diagnostics before issue closure. No integration, playable-build or release claim is made.
