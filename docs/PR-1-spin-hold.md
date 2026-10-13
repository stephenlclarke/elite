# Add explicit Spin Hold with circle recognition and roll-rate HUD

Pull request: [#1](https://github.com/stephenlclarke/elite/pull/1).

V enters Spin Hold; a deliberate one-finger circle around the pad centre selects pilot-relative CW or CCW and commands 12 degrees/second. One stable finger reduces the magnitude, two hold and three increase it at 6 degrees/second per second, capped at 60. Hands-off holds the rate; B or V commands a smooth stop at a response limit of 24 degrees/second per second. Opposite circles reverse through zero. Native AppKit touch values send intents to actor-owned simulation state.

Contact changes settle for 120 ms before adjusting speed. Two-finger aiming rebases on every count change and supplies pitch/yaw without centroid jumps. Circle recognition is exclusive to Spin mode and never applies the tracing movement to aim. It requires a 300-degree sweep, 16 meaningful samples and 85% directional consistency within the normalized 0.12-0.46 centre ring; jumps above 45 degrees reset it. HUD lines show mode, direction/arrow, actual rate, differing target and recognition/adjustment feedback. Keyboard alternatives and menu actions are available.

Tests exercise both circle directions, arc/reversal/jump rejection, sustained hands-off roll, contact debounce, bounded acceleration, slowing without reversal, smooth opposite commands, frame-rate-independent rate/rotation, forward-heading preservation, cockpit direction labels, rebased native aim and focus/pause/help/docking cancellation. `make ci` supplies full coverage and sanitizer/leak evidence. The README and contextual flight guide document the prototype. These thresholds are chosen defaults; physical multi-finger delivery and user usability remain unverified, and the app does not alter macOS gesture settings.

Local validation: 66 tests passed, 93.26% coverage across all Swift sources, passing Thread/Address Sanitizer and zero leaked bytes in the native actor/mission/frame probe.

Request: [ISSUE-spin-hold.md](ISSUE-spin-hold.md).
