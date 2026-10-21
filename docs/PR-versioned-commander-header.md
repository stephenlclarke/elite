# fix(save): distinguish versioned commander headers from legacy input

The schema 21 archive reader now selects `currentCommanderHeader` for its bounded, hash-checked Commander chunk. That namespace permits native station state belonging to the versioned header while still rejecting misplaced RRS and native mission/contract custody. Actual raw Commander loading and pre-21 headers continue through the unchanged raw namespace. See [the common load failure](ISSUE-versioned-commander-header.md).

All later decoding, schema restrictions, retained-world consistency, equipment-owner joins and native restoration checks remain. The private save barrier still rejects unproved docking custody before writing; this change grants no authority from a raw Commander or authored query facts.

The existing genuine RRS/main save/load cases now additionally assert schema 21 and require refusal of the same archive pointer downgraded to schema 20. They retain actual doorway entry, full Commander/file conservation and fresh service epochs. The misplaced-RRS test checks both raw input and current headers. All existing raw laundering and absent/null compatibility cases remain; no new broad test lane is introduced.

Strict Swift source lint, Markdown lint and whitespace checks pass. Runtime execution remains pending in the next combined frozen gate. Full 195 failed with 37 issue headers and signal 10; this concrete shared-reader defect explains a legitimate versioned refusal path, without claiming it explains every failure or the separate debugger crash. Renderer fingerprints must be regenerated after this Core change. Completed external review, final-head checks and protected merge remain separate release gates.
