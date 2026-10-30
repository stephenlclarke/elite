# Discover authenticated drafts before publishing a release

## Problem

The v1.5.0 publisher created one draft with the five verified assets at the planned source, then failed when the by-tag endpoint returned 404. Authenticated release listing and lookup by that draft's ID worked. The same draft was recovered without rebuilding or regenerating artifacts. A retry must discover that existing draft rather than treating the by-tag 404 as permission to create another release.

## Required behavior

Use authenticated, paginated release discovery and fetch the unique matching release by ID. Require the exact planned tag and source in both the list entry and fetched detail. Refuse ambiguous discovery, changed identity or source, missing post-upload state and API errors. Preserve exact main/quality/tag checks, immutable local artifact and remote asset verification, partial-draft retry, no overwrite, and the final public-release receipt guards.

This is a maintained publisher correction on `ca2e5b2865f808e1d3c4fde4e7f076b6c7a9ce09`. It does not alter or gate the separate M01 public verification. See the [implementation and validation](PR-release-draft-discovery.md).
