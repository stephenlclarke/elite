# Fix authenticated release draft discovery

## Change

`release_macos.py` now discovers releases with the repository's existing authenticated `gh api --paginate --slurp` convention. It selects exactly one entry for the planned tag and fetches that entry by ID. Both responses must name the exact planned source; the detail must also retain the listed ID and tag. Initial discovery with no match permits normal draft creation. Successful discovery is required again after creation or upload, and an existing release must retain its ID. A failed lookup or ambiguous match never authorizes a duplicate draft.

The main source, quality check from app 15368, tag no-overwrite, signed local artifact, checksum, notarization, existing asset digest/inventory, missing-assets-only upload and final public-release checks remain in place. The final published-state guard still uses the public by-tag route after publication. The workflow and commands stay unchanged; no rebuild, artifact regeneration or operator fallback is added. Only the publisher, its Python tests and this paired issue/handoff change. No live network, authentication, tag, upload, release or public receipt operation ran during validation.

## Validation

All 11 focused publisher tests pass, including the six existing test bodies unchanged. The regressions cover draft creation when the by-tag route returns 404, resuming the authenticated existing draft without a second create or overwrite, mismatched list/detail source and ID/tag, ambiguous matches, all-page discovery, lookup error propagation and post-upload missing/changed/ambiguous state. GitHub reads, mutations and public verification are mocked; artifacts use temporary fixture files.

The two draft-404 regressions also ran against the original `ca2` publisher loaded in memory. Both failed at its by-tag 404 as expected; the fixed publisher passes the same cases. All 44 distribution Python tests pass. Scoped Markdown lint and whitespace checks pass. No Swift compiler, native application, GUI/GPU, probes, shared ledger or G1 checkout was used or changed.

## Compatibility and remaining review

This preserves the existing strict requirement that `target_commitish` equal the planned commit SHA. Authenticated discovery must succeed; permission errors and service failures propagate. These deterministic tests do not qualify a new real publication. The frozen packet still needs independent review before push, PR or integration. M01's actual public download verification remains separate. [Problem and scope](ISSUE-release-draft-discovery.md).
