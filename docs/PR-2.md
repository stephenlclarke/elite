# feat: add navigation computers and responsive flight assistance

Historical delivery handoff: its navigation/shield names and prices describe that checkpoint. Current component grades, stock values, upgrade progression and retained save-key mappings are documented in [Equipment modules](EQUIPMENT-MODULES.md).

Modern Mac windows now use full-width smooth flight graphics, compact original-font instruments and a larger scanner. Stable targeting, full station docking and contextual mission browsing accompany fuel-limited route planning and a grouped equipment shop.

## Behaviour

- Render native-resolution wireframes, opaque optional panels and small point stars. Label instruments and missile states, resize the cockpit and generate README media through the live renderer. Bundle a renderer-generated Cobra Mk III app icon and display it beside README badges.
- Provide six cumulative targeting tiers, a live target camera and honest unavailable NPC telemetry. R cycles visible ships, offscreen ships and stations according to tier. C directly engages geometry-checked station guidance; Q/P/manual controls cancel. Migrate standalone docking equipment to at least Docking targeting tier.
- Complete docking through safe approach, facing/phase/rate matching and final braking. Attribute ECM destruction to the player's actual field; Military return fire requires a confirmed attacker, ammunition, cooldown and forward lock. Use a shared actor-owned voice queue for gameplay events.
- Add counted fuel storage: four additional 7-LY units at 2,000 CR each, fitted empty. Basic/Advanced/Military navigation costs 1,000/3,000/9,000 CR and caps jumps at 7/14/21 LY, reduced by current fuel. Search uses capacity+7/capacity+14/whole galaxy respectively. XYZzy receives all units and Military navigation, without bypassing jump limits.
- Add route alternatives and saved progress, docking-stop advancement, launch preloading, manual H jumps and paid refuelling before auto-trade exports. Charts have radius-sized planets, geopolitical colours, all-galaxy search and separately labelled search/max/fuel rings with Z zoom.
- Group equipment in a centred compact table with non-purchasable headings, item-identity selection, mouse/scroll controls, right-aligned prices and visible reward/unavailable states. Add independent Front/Left/Right/Rear laser mounts, mount-specific firing and fitting, complete status/inventory summaries and legacy-save migration. Colour market categories consistently while keeping explicit purchase availability. Shade startup ships without changing flight preferences. Apply damage-ratio shield capacities and the once-earned Elite Capital reward. Naval lasers use the documented 64-damage native prototype.
- Grant XYZZY 1,000,000 CR once and keep normal cash accounting thereafter; migrate old unlimited-cash saves once. Preserve individual options on re-entry. Fit scoops and collect native cargo/inactive Thargons.
- Announce player-attributed target kills as Target destroyed with once-only voice, preserving Target lost for unrelated removal and normal rank/bounty events.
- Open a read-only two-mission Gallery from station or flight, freeze and restore AUTO/Spin, and expose chronological milestones without advancing missions or granting rewards. Preserve all ship and shipyard research.

## Validation

`make ci` exercises deterministic and native tests, overall coverage, Thread Sanitizer, Address Sanitizer and a native lifecycle leak probe. Focused regressions cover every nav/storage/fuel combination, save migration, actual C docking, grouped purchases, shield capacities, target cycles, speech attribution, mission stages, responsive bounds and complete ship silhouettes. Native windowed/fullscreen equipment, chart and docking checks supplement renderer assertions. README media uses `make readme-media`; Swift, shell and Markdown formatting are checked.

Validation on 2026-10-13: 139 tests passed with 94.92% overall Swift coverage; Thread Sanitizer and Address Sanitizer passed, and the native lifecycle probe reported 0 leaks / 0 leaked bytes. Native smoke checks confirmed C engagement, shaded startup ships, four mount/status summaries, category-coloured market availability and grouped equipment in windowed/fullscreen layouts. Compact-layout tests cover 512-point widths. Swift formatting, Markdown lint, shell checks and regenerated README media passed.

## Compatibility and limits

Old JSON commanders remain readable; legacy docking, XYZZY cash and Elite rewards migrate without downgrading higher equipment. Route figures assume station refuelling and estimate market opportunities; future fuel affordability is not guaranteed. NPC fuel/shield/cargo telemetry remains explicitly unavailable where not modelled. Solar scooping and original binary-save compatibility are not implemented. Safe docking from inside station geometry is not guaranteed. These native additions do not claim complete historical physics or blueprint parity. Only the two implemented BBC missions are playable; cross-version research stays separate.

Request: [ISSUE-2.md](ISSUE-2.md).

Pull request: <https://github.com/stephenlclarke/elite/pull/2>.
