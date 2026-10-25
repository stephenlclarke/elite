# Automate source-bound release versions

## Problem

Packaging defaulted to a manually entered version, while Homebrew separately accepted a version and artifact commit. That could disagree with Conventional Commit history or with the actual signed/public download. M01 must ship before M02, with later milestone source excluded and each release calculated independently.

## Required behavior

Generate SemVer from the highest published stable ancestor tag and actual non-merge Conventional Commit history. Recognize breaking headers/footers, feature and fix/performance impact; refuse invalid history, collisions and no-release publication. Preserve preexisting history, treat real merges and squash commits explicitly, and bind one plan to the exact main source and classified history. All release consumers must validate that same plan and actual artifact evidence. Partial upload must never be reported as successful publication.

## Scope and verification

The change is confined to Python distribution tools, their Make targets, focused fake/Git-fixture tests and workflow documentation. No Swift/game state, schema, actor ownership, diagnostic probe or extra native run is included. Source/history/version/artifact mismatch, unavailable main quality, incomplete/corrupt upload, draft resume and shared consumer propagation receive focused tests and one independent delta review. Final-head required CI/review, main analysis, actual signing/notarization, release and tap verification remain necessary. Preview numbering is not a publication claim.
