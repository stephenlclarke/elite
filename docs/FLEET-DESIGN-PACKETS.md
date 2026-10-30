# Fleet design packets

The [fleet r3 design packet](fleet-design-v2/README.md), authored as revision 2.2, is the current reviewed design reference. It supersedes earlier r1/r2 design proposals for future implementation. Read its [revision history](fleet-design-v2/REVISION.md) and [bounded corrections](fleet-design-v2/REVIEW-CORRECTIONS.md) with the frozen contracts. Earlier archives and runtime evidence remain historical records; no existing implementation is replaced by this import.

All 208 imported files preserve the reviewed archive bytes. Archive SHA256: `4392dd6eb5a289145c88e5cef3ec3f83552d7920d9dc3bbb3331b8539c11ec9a`. The unchanged [manifest](fleet-design-v2/MANIFEST.json) has SHA256 `795a78d50a1e9fc5aae9d0267d892d0765d097a9feb8d85b7931f035d8525e44` and pins its other 207 files. The packet's own handoff wording is preserved as authored; subsequent bounded review clearance is recorded here rather than rewriting frozen inputs.

The original r3 reviewers cleared their scoped correction findings: G3 naming/acquisition (`e4e33da651600a5a3249c0adcf343d76e5b94285f8d8454eb993d39b7f1e1641`), MC1 fitting/crew/Medusa (`c7c093e3cb835bf5f74159814044bdbe530b1722225c9340134125b80c10b9db`) and G4 physical/Tithe (`b225448fd252511a3da1d4f0bd904f0e2432a73bc0615e83d8fba02abee0f65a`). These are design reviews, not runtime or visual qualification.

The packet contains 171 base-hull contracts, three Tithe conversion designs and associated documentation, source authoring scripts and reference assets. Numerical values, fitting/crew rules, proposed names, geometry and acquisition contracts remain design proposals. This import does not adopt them into game resources or code, execute the authoring scripts, activate Redtail/Besra, grant ownership or equipment, or qualify a playable fleet. Runtime implementation and its tests require their own bounded source changes and review.

See [the import issue](ISSUE-289-fleet-r3-design-packet.md) and [PR notes](PR-289-fleet-r3-design-packet.md).

The design-only import is tracked in [PR290](https://github.com/stephenlclarke/l337/pull/290). Its actual rebased-head review and required checks follow the separately qualified SDK prerequisite [PR293](https://github.com/stephenlclarke/l337/pull/293); the preserved original precompile failure provides no native qualification for the design packet. No frozen archive file is changed by this context update.
