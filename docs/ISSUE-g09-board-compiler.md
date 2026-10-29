# G09 board compiler compatibility

## Problem

Hosted Swift 6.1.2 cannot type-check the optional-map expression concatenating five arrays for the G09 custody review token. CI 39513515600 fails at NativeIdentifiedSalvageBoard.swift:121 before the required checks complete. Local Swift 6.4 success does not establish hosted compatibility.

## Required behavior

Preserve the exact permission, capture order, loss order, held order and reception-or-open sequence, joined with a colon, plus the unallocated fallback. Split the expression into explicitly typed local values and ordered appends without changing review or custody authority.

## Acceptance

See [correction notes](PR-g09-board-compiler.md). Existing meaningful board journey, stale-page and writer-refusal units plus hosted Swift 6.1 CI qualify the correction. No new mirror test, schema change or gameplay feature is needed.
