# Add contextual help and XYZZY ship display modes

## Behaviour

K, Command-K and the Help menu open a paged guide for the current screen. It pauses simulation and suppresses transient game messages while open. Number-key navigation is documented by context alongside flight, trade, equipment, chart, pause and secret controls.

XYZZY 0 cycles white wireframes, hull-coloured wireframes and opaque shaded panels. Panels use directional flat lighting, near-plane and viewport clipping, and back-to-front ordering. Both the deterministic raster path and native presentation support the styles. Station entrances rotate with their hull and are shown on the visible entrance face. The saved style is optional in the commander format, so old saves default to white.

New commanders are Jameson with standard equipment and 100 credits. Entering XYZZY changes the name to Clarke, fits all equipment and restores ship resources, preserving cargo, cash, location and progress. Unlimited fuel and hyperspace distance remain at secret keys 4/5; paused @ is removed.

## Validation

Tests cover menu cycling, Clarke upgrades and progress preservation, save round trips and legacy decoding, coloured-line geometry, opaque clipped panels, near-plane crossings, face lighting, nearer-ship occlusion, native coloured/shaded output, the Help menu action and restoration of every screen from help. Existing complete-rotation regressions remain in the suite. `make ci` also runs thread/address sanitizers and the native leak probe, which exercises all styles and help transitions.

The native app was inspected for the Jameson start, secret selector, shaded flight and flight help. README controls and generated media are updated with the final implementation. Authoritative Sonar analysis uses committed main with the exact SHA.

## Compatibility

Existing saved names and equipment are retained when loading. The Jameson default applies to new games; Clarke upgrades occur on entering XYZZY. Display additions are intentional extensions to the BBC Executive target, not claims of original rendering parity.

Request: [ISSUE-player-help-and-display.md](ISSUE-player-help-and-display.md).
