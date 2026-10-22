# Recorder inertia fixture loses both actors to normal culling

[Issue 89](https://github.com/stephenlclarke/elite/issues/89) records both manual and work variants expecting two original actors but observing zero in hosted run 39767872407. The physics fixture projects the authored Navidor source into the far-away arrival frame. Normal culling removes both bodies, making its displacement loop vacuous. Keep normal culling and source poses intact; place only the controlled test observer near the same source. See [the correction](PR-89.md).
