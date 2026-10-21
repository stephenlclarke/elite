# Prepare weapon presentation before publishing runtime snapshots

The weapon-status getter performs native mesh/ray queries and, for EMP readiness, validates the whole Commander. Cockpit layout accesses that getter during native UI painting, repeatedly doing simulation-side work on the main actor. Its actual runtime cost has not been measured.

The runtime actor should prepare the immutable weapon/status projection at the existing snapshot boundary, after accepted work, refusals, rollback and input transitions. Painting should consume the delivered text without deriving readiness. Native producers must retain every emission and publication check, independently of presentation. Directly constructed offscreen scenes should prepare their projection explicitly before rendering.
