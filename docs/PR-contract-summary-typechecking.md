# fix(display): type contract summary subexpressions

The combined contract-board summary exceeded Swift's expression type-checking budget. Its RRS, pledge and ordinary offer formatting now use explicit `String?` locals, with an explicit `String` final fallback. The original priority, text, numeric formatting, preview queries and row/action rendering remain unchanged. See [the compile issue](ISSUE-contract-summary-typechecking.md).

## Validation and limits

Strict Swift source lint, Markdown lint and whitespace checks pass. Checkpoint 175 records the actual pre-fix combined source `bca67bbc92995f15d2e90ce7791e736153d85f94` compile failure, raw log SHA256 `4af3f64b73071ac0fea0fb4135f193b7033892ed58c454f3c14cada537da6ef5`. No media output was produced; protected inputs and owned-process closure were verified.

This repair has not yet been compiled or executed. The coordinator must retry actual renderer generation, currentness, focused feature tests and final composed `make ci`. No runtime pass, generated media, sanitizer/leak result or release acceptance is claimed. The change adds no new behavior or test-selection exception. Completed external review, final-head checks and protected merge remain required.
