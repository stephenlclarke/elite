# Describe the current EMP charge and electrical effects

The guide now explains held Return, the ten-second charge, release revalidation and ECM cancellation; current range/power scaling; shield-first electrical drain; release costs; and occluded distance-attenuated splash, including possible player exposure. A partial drain is distinguished from zero-reserve disablement. The starter name agrees with NewCommanderDefaults, and the obsolete universal save-version statement is removed.

## Validation

Documentation-only source comparison uses EMPPulseProfile.swift, EMPElectricalRuntime.swift, NewCommanderDefaults.swift and the existing strict save loader on public6b6ed6cec08c89e4bf00828c631da99d62acae26. Markdown and local-link checks are required. Existing charge, attributed-ECM cancellation and shield-first electrical tests provide semantic coverage; this guide update does not request another native run. Independent review remains pending.

## Scope and limitations

Only TARGETING-COMPUTERS.md and these paired notes change. Mining/hold guidance, current source, saves, inputs, tests and active release fixes remain unchanged. This guide describes development source; no new usable feature, complete campaign, release or Homebrew availability is claimed.
