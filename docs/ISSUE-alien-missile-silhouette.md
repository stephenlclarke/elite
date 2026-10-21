# Give alien missiles a distinct physical silhouette

FR-028 requires alien missiles to look different from standard missiles. Both profiles currently use the missile hull mesh. A distinct colour alone would disappear in white wireframe mode and would not provide a distinct physical silhouette.

Use the actual projectile ordnance profile to select one recognizable forked mesh for drawing and collision. Include it in gameplay mesh overrides so bridge collision paths also receive the same geometry. Preserve the missile hull identity, existing style colours, threat classification and all weapon tuning. See [implementation](PR-alien-missile-silhouette.md).

Composed check 248 stopped during compilation before any test executed: Testing macros cannot invoke mutating actor/attack-origin allocators through immutable closure values, and the key-path `allSatisfy` macro expansion lost its rethrows context. The correction stages each actual allocation/result in a local before asserting it; geometry and all assertions remain unchanged. The original failure evidence is preserved.
