# fix(ci): preserve immutable phase evidence during checkout cleanup

## Result

The existing Git clean command excludes `/reports/quality-phases/` alongside `/.build/`. Successful immutable evidence survives the next guarded checkout. All other ignored/untracked cleanup remains, including unexpected source files. No proof bytes/modes, authorization predicate, source check, phase validation, resource allocation or workflow role changes. See [the issue](ISSUE-m01-phase-evidence-cleanup.md).

## Validation

All nine existing local-runner tests pass. The cleanup regression now uses an actual temporary Git checkout containing a 0400 proof in a 0500 attempt directory. It checks proof bytes, inode, mtime and modes plus cache survival, and removes unexpected source, an unrelated report and a similarly named nested path. Original cleanup loaded only in memory fails this same test with CalledProcessError; corrected tracked source remains unchanged. The existing unit workflow already runs this test target.

A separate private copy of the actual remaining report tree reproduced the original command's exact permission-denied file paths. Original native evidence was not cleaned or chmodded by these checks. The follow-up still needs review and actual final-head checks; main-only Sonar and release publication remain downstream. Prepared source/unit results do not replace those outcomes.
