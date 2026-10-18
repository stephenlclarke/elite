# Mission pack file and folder routing

The native Install Mission Pack panel and `--validate-mission-pack` originally accepted only legacy TOML files, although the engine already had a protected schema 2 folder reader and immutable installer. Users could only install schema 2 content manually and restart.

Route actual directory selections to `ScriptPackLibrary` and regular file selections to the existing legacy provider, without parser duplication, failed-folder fallback or symlink resolution that bypasses either reader. Keep AppKit panels on MainActor and installation on GameRuntime. Content validation must remain distinct from runtime availability: unsupported capabilities and declared dependencies can leave a well-formed installed pack unavailable.

This allocation is based on `ea6e6ef85502f336244f183b2269859693c43232`. It changes engine input routing, tests and documentation only. Mission content, branding, controls, interpreter limits, dependency semantics and capability support remain outside this slice. R21 remains partial; full engine readiness remains false.

G1 owns combined compilation, focused validation, CLI/picker acceptance and full gates. No build, test, GUI, query or reproduction job ran during source authoring.
