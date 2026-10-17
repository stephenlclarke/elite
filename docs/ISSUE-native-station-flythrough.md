# Diagnose the incomplete blue object and apparent fly-through

## User report

During the actual native flyby the player saw a large blue object that appeared incomplete and seemed to be crossed by the ship. The preserved compact rear screenshot is visually consistent with the native RRS waystation, which has an open central ring and two arms, but the screenshot alone cannot establish the exact source or whether the effective player hull touched its structure.

## Evidence and required result

Validation 309 reused the exact reviewed 293 application. Compact completed 1423 distinct drawn frames. Fullscreen stopped before finishing its trajectory. The old failure guard combined key-window, visibility, docked and flight-screen checks, so the failure text does not establish focus loss alone. Preserve both reports and the original scene, seed, path, application bytes and protected user files.

The waystation center is approximately [468.8903, -112.6671, 3727.7742], close to the original straight +Z path. Planet and sun clearance does not prove station clearance. Diagnose actual station binding, rendered/canonical pose, source mesh, effective-hull sweep and image before accepting native visual correctness. Correct a real rendering or collision defect if confirmed; do not remove the station or relax the original guard to obtain a passing measurement.

## Link

[PR-native-station-flythrough.md](PR-native-station-flythrough.md).

## Confirmed diagnostic result

Validation 310 identifies body 10, actor entity 4, `rescue_station-g0-s151` version 1.5.4 in the original industrial flyby. Across 1423 observations the rendered/canonical poses remain consistent, no resolved sweep is blocked and player energy/shields remain full. The recorded close view reproduces large partial blue panels, but this trajectory does not penetrate solid geometry. Independent component audit proves inward exterior faces and outward-facing open liners/bays; the separate damage-only response still permits travel after genuine solid contact. Both need correction, without misreporting this particular flyby as a collision.
