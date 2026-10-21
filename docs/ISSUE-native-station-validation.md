# Repeated complete station checks delay physical flight tests

## Problem and evidence

Validation 311 compiled successfully, completed 23 of the 27 selected methods and reached its unchanged 600-second limit with four physical flight methods unfinished. The outer supervisor preserved the failure and closed all owned process identities. Its exact binary and 687 compiled artifacts are preserved under `/tmp/elite-native-station-structure-focused-311/tsan-snapshot` before further compilation.

One authorized one-second coarse sample of that actual helper showed repeated `NativeStationWorld.valid` calls through station population, body binding and condition persistence. Those calls repeatedly validate 372 source records. The sample identifies a candidate hot path; it does not establish native frame rate, a deadlock or a measured optimization result.

## Required behavior

Reuse a successful validation only for the complete unchanged semantic station-world value. Every changed owner, source descriptor, actor binding, tombstone, pose, energy condition, main-station observation, receipt or sequence must face the original predicate. Decoded files cannot provide a validation witness. Preserve value semantics, checked Swift 6 concurrency, save bytes and all existing gameplay checks. Do not increase time limits, reduce physical fixture iterations, serialize tests or treat the incomplete run as passing.

## Link

[PR-native-station-validation.md](PR-native-station-validation.md).
