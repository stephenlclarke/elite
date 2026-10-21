# CR-06: Automatic control bypasses hull limits

Ordinary target facing used fixed pitch/yaw limits and station guidance used fixed roll and thrust values. The runtime applied those outputs directly after scaling manual controls by the selected hull. A slow heavy hull could therefore maneuver faster under automatic control. Station avoidance could also assign an outward velocity instantly.

Automatic commands must respect actual hull angular rates and world-unit thrust. Avoidance must spend the same thrust budget as ordinary approach, and impossible station spin matching must remain visibly blocked. Implementation and validation: [handoff](PR-CR-06-autopilot-hull-limits.md).
