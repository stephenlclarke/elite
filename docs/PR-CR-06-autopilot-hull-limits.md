# CR-06: Bound automatic maneuvering by the actual hull

The runtime supplies the same actual hull limits used by work guidance. The controller retains its existing conservative speed and rate policy where that is below hull capability, caps pitch/yaw/roll by the selected hull, and applies one translational thrust budget across approach, braking and station avoidance. Existing overspeed brakes gradually. Stopping-distance avoidance replaces the instantaneous outward-velocity assignment. Guidance that begins too close to stop cannot promise physically impossible clearance.

A station whose projected spin exceeds the hull roll limit holds with an explicit status rather than claiming final approach. Standalone callers retain the old policy defaults. Four regressions cover actual heavy-hull target/docking commands, near-station bounded correction, inherited overspeed and infeasible doorway spin. Existing full approach and close-rear launch tests remain required compatibility checks.

Validation is pending the numbered validation lease. Source formatting and whitespace checks pass; no executed build, test, sanitizer or native result is claimed. Motivation: [issue](ISSUE-CR-06-autopilot-hull-limits.md).
