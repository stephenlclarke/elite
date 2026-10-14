# Startup continuation and build identity

Delivered together in [PR #11](https://github.com/stephenlclarke/elite/pull/11). See [the integrated validation and release evidence](PR-11.md) and [request checklist](DELIVERY-BACKLOG.md).

## Implementation

Adds a startup-only runtime restoration path that loads in memory and resets presentation to the title. Startup displays use bundle version and full revision metadata; the local launcher embeds Git build identity alongside the distribution packager's existing identity.

## Validation

Focused StartupSaveTests cover title continuation, unchanged save bytes, normal Open behavior and exact/malformed build metadata. Shell syntax and full Swift test suite are checked before handoff. The final integrated `make ci` passes 268 tests, 93.27% coverage, both sanitizers and zero leaks; signed native startup/Continue and exact 1.3.0 identity checks pass.

## Compatibility and risks

No save schema changes. Bare SwiftPM executables have no Info.plist identity and explicitly report unavailable commit metadata. README media is regenerated only by make readme-media during integration.

## Linked issue

ISSUE-11-startup.md
