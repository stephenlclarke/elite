# Hollow visible hulls can miss a centre-only glow ray

Independent read-only geometry review of the initial EMP source found that the actual SH063 Imperial Courier at identity orientation, zero rotation and position (0, 0, 1000) has no mesh intersection along its body-centre ray. Real surface rays do intersect its authored triangles. A centre-only visibility prerequisite therefore suppresses a hostile Courier's world cue despite its visible hull.

The initial authored acceptance also needed target-attributable hostile-missile HUD/world assertions and actual GameView pixel capture, rather than allowing another red object to satisfy an any-red assertion. The native cutter test needed to require its intended cargo surface before firing. See [implementation](PR-target-cue-surface-visibility.md).
