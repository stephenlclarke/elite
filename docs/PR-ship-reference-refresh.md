# Refresh ship media and reconcile the SH025 reference

Source integration invalidates the maintained animation fingerprints. Refresh all171 through the actual game renderer, and align the retained SH025 balance row with the approved Peregrine Mk V specification. Runtime ship definitions and geometry stay byte-identical; historical 12t/0t source facts remain separate from the current 92t/35t profile.

The existing catalogue regression requires the exact SH025 name, family, profile and current specification, while retaining the historical expansion check for all other hulls. No generator guard or fingerprint dependency changes.

Validation: six directly affected catalogue tests PASS; `make ships` finishes by reusing all171 completed renders; `make ships-check` reports every TOML/GIF/reference current. The initial generation failure and subsequent correction are preserved in `/tmp/elite-ship-media-931`. Only SH025 GIF, overview and fingerprint manifest change among media assets. The catalogue and provenance documents are generated outputs.

Combined CI checkpoint930 previously passed flight9/distribution22 tests and stopped at ship references. Coverage, threading, address safety and leak gates remain pending. Independent source/data review precedes this local commit; final-head GitHub review/checks and committed-main SonarQube remain required before publication. See the [issue](ISSUE-ship-reference-refresh.md).
