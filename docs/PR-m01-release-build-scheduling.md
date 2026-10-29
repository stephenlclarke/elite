# fix(distribution): serialize universal Release compilation

The packager's existing build vector now includes `--jobs 1 -Xswiftc -disable-batch-mode`. Both the universal Release build and the same vector's `--show-bin-path` query inherit those arguments. Release configuration, distribution scratch path, arm64/x86_64 selection and all packaging/verification behavior remain unchanged. No wrapper, policy framework, CLI override or asset protocol is added.

The existing fake release-plan test stops at `create_bundle` before native packaging. It now checks both exact command vectors and their capture options, independently of the implementation's shared list. It still checks that the single generated plan controls the bundle, archive, tag, README and cask. All tool calls in that selected test are mocked; its files are temporary fixtures.

Focused offline validation passes the changed Python test. A negative control loads the original packager function into memory: the same regression fails because the scheduling arguments are absent. Tracked source stays corrected. Python compilation without bytecode output, scoped Markdown lint and the whitespace check pass. No Swift/compiler/native test, signing, notarization, archive, probe, release-plan generation, publication or execution-root mutation is performed.

These flags constrain scheduling only. They do not prove peak memory fit, account for observer overhead or provide a whole-operation deadline. The previously identified Release-specific resource/authority gap remains separate. No cap is raised, and no normal/ASAN/leaks policy is reused as Release authority. G1 is the sole integrator after its live quality attempt terminates; this source packet is independently reviewed, with final CI/release validation still pending.

Related issue: [universal Release scheduling gap](ISSUE-m01-release-build-scheduling.md).
