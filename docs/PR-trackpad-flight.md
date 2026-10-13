# Add continuous trackpad flight controls

Raw indirect AppKit touches supply a small Sendable input value. Two fingers apply pitch and roll from their normalized midpoint with a central dead zone. One finger brakes to zero and three accelerate to the existing maximum; switching to two or lifting all holds speed. The existing actor update loop repeats held controls and releasing all stops angular movement immediately.

Trackpad commands clear on touch cancellation, loss of focus, pause, help, non-flight screens and docking-computer operation. Keyboard controls still combine within their normal bounds. Four-finger system gestures are ignored until lifted. No private trackpad APIs, global event taps or permission prompts are added.

Deterministic tests cover direction/centre boundaries, contact-count changes, continuously held turns and throttle, speed limits, cruising on release and native cancellation/context clearing. The full quality gates cover actor/thread and memory paths. macOS can reserve three-finger gestures, and physical touch delivery still needs an on-device check with those system gestures configured appropriately.

Request: [ISSUE-trackpad-flight.md](ISSUE-trackpad-flight.md).
