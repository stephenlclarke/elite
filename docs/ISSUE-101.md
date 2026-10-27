# Sorel confirmation lacks a fresh installed-pack check

[Issue 101](https://github.com/stephenlclarke/elite/issues/101) identifies a stale quote that can still confirm after the approved installed Glass Meridian pack is removed or replaced. Saved definition/digest checks and row visibility do not authorize a new live read. The private live ledger reader must join the current exact approved pack and saved mission at every review and final comparison. Historical validation must remain independent of currently installed content. See [the correction](PR-101.md).
