# Sonar findings after showroom integration

The authoritative main analysis of `9612fd42764b2ff6bb08e59a851ac1822b860895` passed its quality gate but reported eight maintainability findings: three nested ternaries, a repeated chart condition, nested home-port conditions, an unused gallery font parameter and two keyboard-help strings misidentified as paths.

The player also reports that the right comparison column starts to the right of its model caption, wasting width and wrapping the required-crew value, and requests the new Cobra design in the app icon. Align the wide selected header/values to that caption without losing narrow-window wrapping; replace the icon geometry through `make readme-media` and update its attribution. This supersedes the earlier icon-preservation request.

Resolve the findings in maintained source without suppressions or configurable keyboard-help text. Preserve screen routing, mission clues, chart geometry, fixed font size and showroom search; keep licence notices consistent with the new icon asset. Validate with the existing meaningful regressions and `make ci`; publish the follow-up Sonar analysis only from committed main with its exact SHA.
