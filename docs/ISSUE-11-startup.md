# Startup continuation and build identity

Delivered together in [PR #11](https://github.com/stephenlclarke/elite/pull/11). See [the integrated validation and release evidence](PR-11.md) and [request checklist](DELIVERY-BACKLOG.md).

## Motivation

Automatic save restoration bypasses the title, and startup credits omit verifiable build identity.

## Expected behavior

Restore the commander without overwriting the save, present the title, and continue the same commander on Space or Return. Show version, repository and exact source SHA in title and credits.

## Compatibility

Explicit Open retains immediate status display. Missing raw SwiftPM bundle metadata is labelled unavailable.
