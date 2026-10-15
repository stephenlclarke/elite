# Preview route alternatives before committing

## Implementation

Show route candidates on the originating galactic or short-range chart. Selecting a candidate changes the preview; Return or Set route commits it. Back or Escape preserves the existing plan. Clip local legs and show continuation cues for offscreen route portions. Keep the existing deduplicated route objectives, tier search radii and fuel-aware hop rules.

README, the player control guide and contextual navigation help describe the same preview/commit/cancel flow and manual travel responsibilities.

## Validation

The initial 24 navigation regressions and 12 route-preview regressions passed. Native checks exercised three distinct Lave-to-Tibedied alternatives on both chart projections at 768 and 512 point widths: keyboard and pointer preview, explicit Set route, local offscreen continuation, Back preserving an active plan and the active-route banner. Independent review identified pause protection and consumed-leg summary issues; fixes and targeted regressions are being completed. The final combined coverage, sanitizer and leak gates remain pending.

## Compatibility and risks

First-leg fuel and later station-refuelling assumptions remain explicit; trade and cargo estimates do not guarantee profit or affordable fuel. Route selection does not launch, jump or dock. Existing active plans survive preview cancellation. Successful Set route revalidates current capabilities and fuel, then deliberately cancels any pending jump before selecting the new next hop; the status message discloses that cancellation. Stale candidates preserve the active route and pending jump. The separate engine branch must also cancel its calendar admission at this validated commit point when merging this feature.

## Linked issue

[Graphical route alternatives on both charts](ISSUE-route-alternatives.md)
