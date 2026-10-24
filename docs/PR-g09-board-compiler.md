# fix: simplify salvage board custody token typing

## Motivation

Resolve [the hosted compiler blocker](ISSUE-g09-board-compiler.md) at the exact integrated G09 base 99500a9fdc4d7364dc1348d748acd6312bacc583. The overloaded optional-map and array concatenation expression exceeds Swift 6.1.2 type-checking limits.

## Change

Use an explicit String result, optional binding, typed String arrays and ordered append operations. Preserve exactly permission, capture order, loss order, held order, reception UUID or open, colon separation and unallocated fallback. No authority, review token value, save schema or player behavior changes.

## Validation

The actual CI log diagnostic and SHA-256 d598868a6404964b7325a733431c943698be1b568fbd28ec3518e7262bfc75c7 were verified. Strict Swift parser/format lint, paired Markdown lint and diff checks pass. Native compilation and focused existing unit execution are pending with G1, followed by one independent review. Hosted Swift 6.1 validation remains required; no repair claim follows from source checks or a local Swift 6.4 result.

## Scope and links

Only NativeIdentifiedSalvageBoard.swift and this paired issue/PR note set are changed. W05 b341a6a4 remains untouched in its separate worktree. No external PR is created by this correction.
