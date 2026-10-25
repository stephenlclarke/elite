# Derive release versions from Conventional Commits

## Result

One generated release plan supplies the app/bundle version, source-pinned tag, versioned ZIP/checksum/manifest/Apple report, README and Homebrew cask. Highest declared impact since the actual published stable ancestor selects major/minor/patch; documentation/chore-only history produces no release. Actual merge commits are excluded and squash commits retain their declared header/footer impact. Nonconventional history and version collisions fail explicitly.

## Implementation

`release_version.py` owns calculation and source/history validation. Existing packaging consumes its authoritative plan, retains existing signature/resource/architecture/Gatekeeper checks and records Apple's Accepted report. `release_macos.py` publishes a draft only after the exact main quality check and local artifact verification; all uploaded bytes and the exact tag target are checked before publication/success receipt. README and Homebrew consume the same actually published plan/manifest. Existing historical download evidence stays intact. No release/version number is manually selected, and SonarQube still uses the exact 40-character main SHA.

## Validation and boundaries

Focused Python tests cover breaking markers, impact precedence, documentation-only refusal, exact stable-ancestor selection, actual Git merge/squash history, invalid headers, collisions, plan/version/source/manifest drift, consumer propagation, main-quality refusal, corrupt/incomplete uploads and safe draft continuation. Exact frozen source/test receipts and independent delta review are supplied with the release handoff. No Swift/runtime change or duplicate focused 110-test campaign is included. M01's isolated release branch excludes M02/M03/Eagle runtime additions; M02 starts after M01 is released and computes its own version. No new release is claimed before actual final-head gates and publication.
