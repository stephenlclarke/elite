# Disable the optional runtime printer in owned CI children

## Motivation

[Issue158](https://github.com/stephenlclarke/elite/issues/158) records390.06seconds of supplementary Swift backtrace work despite the child printer's30-second timeout. The shared child environment currently forces that printer on.

## Implementation

Change only SWIFT_BACKTRACE enable=yes to enable=no and clarify its purpose. Keep every other runtime option and the parent environment unchanged. The isolated-unit and quality wrappers still use the same common environment helper; actual test commands, failed exits, owned LLDB/normal OS evidence, source/image/process records and all required gates are unchanged.

## Validation

Existing Python tests check disabled effective options, inherited enable=yes override, immutable parent/unrelated environment values, and retained failed-test exit/evidence authority. Run only the two affected crash-artifact/evidence suites. Actual-source review and focused execution are pending. No Swift or game build, runtime diagnostic experiment or workflow/branch-protection change.

## Compatibility and remaining limits

This removes an optional printer's measured overhead; it is not a claim to fix the underlying game crash or close historical144. Full final-head VM/quality, completed-save/reopen qualification, signing and release remain separate. Current runs and any verified superseded cancellation retain their actual status.

At exact97ef5fd7f9b8053eb1e9f6355559863059b81ef2, both affected Python suites passed all70 tests: unittest0.158s, total0.313853s, process exit0. Evidence `/tmp/elite-158-runtime-printer-python-result.json` and raw log. Fixtures execute no Swift child/game build or runtime diagnostic. Independent actual-source review cleared the enable-only change and retained authority tests; independent actual-source/result verification closed158 on this affected scope. Future CI must establish its own runtime outcome; no reduced overhead, game-fault resolution or full quality pass is inferred from these Python results.
