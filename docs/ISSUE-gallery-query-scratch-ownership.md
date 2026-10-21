# Gallery queries retain nested mission snapshots

The qualified coverage failure in official `make ci` run 560 reports `Thread stack size exceeded` / SIGBUS in `campaignGalleryNestedChildUsesImmediateOwnerAndSeparateRootForTrial`. Its page-identity path repeatedly rebuilds the mission catalogue through selected-state, owning-root, trial-availability and link queries while callers retain complete `ScriptInstance` values. The fault occurs while copying another instance in `campaignExecutionIssue` beneath the gallery row's nested optional closures.

The assigned source is `e26595397db8d297978f0b89cd146b782416d49e`. The retained qualification packet is `/tmp/elite-full-review-ci-560/matched-crash-qualification.json`; its matched PID is 51817 and the test image UUID is `5e163b80-b6ff-3425-87fc-533c634f30e4`. The IPS SHA-256 is `4f310d37dd4d5accdae58f9082dd644d939983d2c696895e54d33f529d4f0424`.

Success requires one synchronous gallery read to finish catalogue construction before selected-instance work, avoid full-instance collections and ancestor-loop locals, and preserve exact row order, identity fields, guards, relationship checks, provider freshness and isolated-trial behavior. It must introduce no persistent cache, authority, actor crossing, Game layout/schema change or execution workaround.

[PR-gallery-query-scratch-ownership.md](PR-gallery-query-scratch-ownership.md) describes the repair and independent validation handoff. Runtime stack margin and the original reproducer remain unqualified until G1 builds and executes the frozen leaf with the original stack/concurrency settings.
