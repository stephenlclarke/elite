# Diagnose the incomplete blue object and apparent fly-through

## User report

During the actual native flyby the player saw a large blue object that appeared incomplete and seemed to be crossed by the ship. The preserved compact rear screenshot is visually consistent with the native RRS waystation, which has an open central ring and two arms, but the screenshot alone cannot establish the exact source or whether the effective player hull touched its structure.

## Evidence and required result

Validation 309 reused the exact reviewed 293 application. Compact completed 1423 distinct drawn frames. Fullscreen stopped before finishing its trajectory. The old failure guard combined key-window, visibility, docked and flight-screen checks, so the failure text does not establish focus loss alone. Preserve both reports and the original scene, seed, path, application bytes and protected user files.

The waystation center is approximately [468.8903, -112.6671, 3727.7742], close to the original straight +Z path. Planet and sun clearance does not prove station clearance. Diagnose actual station binding, rendered/canonical pose, source mesh, effective-hull sweep and image before accepting native visual correctness. Correct a real rendering or collision defect if confirmed; do not remove the station or relax the original guard to obtain a passing measurement.

## Link

[PR-native-station-flythrough.md](PR-native-station-flythrough.md).
