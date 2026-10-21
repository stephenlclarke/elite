# Trackpad system-gesture lift latch

## Problem and behavior

Rejecting four contacts or invalid coordinates correctly set the trackpad's wait-for-lift latch. Switching between ordinary and Spin Hold interpretation then called reset and cleared that latch while fingers remained on the surface. In Spin Hold, the invalid-gesture reset could itself cause a mode mismatch on the next event. The leftover contacts could therefore re-arm steering, braking or a spin gesture before the required lift.

Mode changes now preserve an existing rejection latch. Only an empty contact event or an explicit lifecycle reset clears it. Normal mode transitions, two-finger cruise/steering, one-finger braking, three-finger acceleration and spin recognition retain their existing mapping. This pure input-value change does not alter simulation state or actor isolation.

## Verification and compatibility

Two isolated regression methods cover ordinary/Spin Hold rejection after four contacts, dropping to two and then one contact, NaN rejection followed by a mode change, and genuine full-lift recovery. They exercise only TrackpadInput values, with no Game or GameRuntime journey. Both methods are added to the fixed GitHub unit selection; all six report-check Python fixtures pass. GitHub compilation/unit execution and MBA code/result review are asynchronous; no unrun result is claimed.

The unit workflow now lets its running branch job finish instead of cancelling every cold compile on a new push. The newest pending source can use the resulting incremental cache. This does not block coding/pushing, add a gate, alter required protection, run integration tests or enable a Sonar scan outside main. The README documents the required full lift.
