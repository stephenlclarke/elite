# Split contract board summary inference

The contract board summary fails Swift type checking after the induction summary addition. Replace the long optional fallback chain with sequential assignments to `preferredSummary: String?`. Each assignment keeps its original guard and string, and runs only if the preceding result is nil. The fallback priority and final displayed summary remain unchanged.

Refs #35. [Failure evidence](ISSUE-35.md) links the affected hosted run. Only `ContractBoardDisplay.swift` and these paired notes change. No syntax-mirroring tests are added.

Validation: strict Swift formatting, Markdown lint, diff checks and a source comparison of the ordered guards/strings and surrounding unchanged code pass. No local build or test execution. The existing 74 pure units run on GitHub after push; compilation and actual unit results remain pending independent MBA verification.
