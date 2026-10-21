# Campaign gallery tests validate against the old menu delegate

Mission menu installation assigns each item's target to `NativeMissionMenu`. That target updates the current action title and validates both action availability and the actual painted page proof. Two campaign gallery tests instead invoke the legacy `AppDelegate` validator, which defaults to enabled for these commands and does not update their mission titles. The full run consequently reports saved-contract trial, campaign title and post-retry availability failures.

Validate the actual installed mission targets while retaining real menu dispatch, painted frames, stale-proof rejection, actor commands, duplicate retry and Commander/save assertions. See [implementation](PR-gallery-installed-menu-validation.md).
