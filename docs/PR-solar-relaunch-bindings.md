# test(solar): verify retained station world across relaunch

The existing dock/load/relaunch test now constructs its expected native station state from the saved world. Every current living station must have an actual body whose actor belongs to the new system visit and differs from its old binding. Only those bindings and the current main-station observation change in the expected world; the full Commander comparison remains. No production code, authority checks, receipt history or original solar assertions change. See [the failure](ISSUE-solar-relaunch-bindings.md).

Strict Swift source lint, Markdown lint and whitespace checks pass. Execution is pending in the next combined maintained gate; this source correction is not runtime acceptance.
