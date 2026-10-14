# Startup continuation and build identity

## Implementation

Adds a startup-only runtime restoration path that loads in memory and resets presentation to the title. Startup displays use bundle version and full revision metadata; the local launcher embeds Git build identity alongside the distribution packager's existing identity.

## Validation

Focused StartupSaveTests cover title continuation, unchanged save bytes, normal Open behavior and exact/malformed build metadata. Shell syntax and full Swift test suite are checked before handoff. Final integrated make ci remains with the main implementation session.

## Compatibility and risks

No save schema changes. Bare SwiftPM executables have no Info.plist identity and explicitly report unavailable commit metadata. README media is regenerated only by make readme-media during integration.

## Linked issue

ISSUE-startup-fixes.md
