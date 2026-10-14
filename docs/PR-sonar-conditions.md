# Simplify chart and celestial display conditions

## Motivation and implementation

The first main scan of the integrated 1.3.0 release identified three nested conditional expressions. This follow-up separates the docked chart footer value and makes horizontal and vertical celestial bearing choices explicit. Thresholds, labels, chart geometry and simulation behaviour are preserved. The distribution default advances to 1.3.1 so its source identity includes the cleanup.

## Validation

Existing celestial HUD/four-view and compact-chart regressions cover these branches. Complete `make ci`, renderer media, signed/notarized packaging, protected publication and an exact-main Sonar scan are required before delivery.

## Compatibility

No ship geometry, gameplay specifications, save schema or mission-engine changes are included. The separate mission-engine branch remains independent. The released 1.3.0 archive retains its original source identity.
