# Frame deadline drift after late wakes

Matched candidate profiles 497 and 498 on `b0e4108991293e6a04a85f8640a913563e2e6b4f` measured median draw intervals near 17.7 ms, about 56.45 reciprocal FPS, in compact 1024x1080 and fullscreen 3600x2260 views. Processing p95 was about 7.6/7.4 ms and draw p95 about 3.8/4.3 ms. Compact's application profile completed successfully with a separately recorded post-run harness error; it was not retried. These measurements do not establish physical scanout timing or attribute all latency to scheduling.

The maintained loop calculates every deadline from that iteration's actual frame start and sleeps with unspecified tolerance. A late wake therefore becomes the next time origin and permanently shifts subsequent deadlines. Overdue work currently yields and can immediately start another iteration rather than waiting for a future cadence slot.

Use one phase-anchored cadence with explicit small sleep tolerance. Skip missed slots after overdue work, re-anchor on effective refresh-rate changes and preserve the dynamic 1...60 FPS cap, real elapsed simulation delta, MainActor isolation and cancellation. Matched after profiles are required before any performance improvement claim.
