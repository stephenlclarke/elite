# Stop-state momentum and refused hot-work advance

The independent flight/work run 488 retained 25 passing methods and recorded five issues in the four-argument refused-hot-work stop method. Q's immediate world-velocity equality failed: the exact vector `(20, -10, 50)` became `(20, -10, 50.000000000000014)` after world-to-local-to-world conversion. All four arguments also failed the complete Commander/body equality after their existing single actor advance.

The actor prepares clocks and preflight work before `Game.tick`, then performs actor/body restoration afterward. A tick can return immediately when its initial hot-work flush refuses, yet these surrounding actor phases still execute. A safety stop must admit that publication boundary before any advance phase, including when the native view resubmits a Return key that remains physically held.

Keep custody, hot-session, physical pose/body and whole-Commander rollback comparisons strict. For momentum only, use the established `1e-9` norm of the full vector difference from the existing Q/work-release regressions; this accounts for frame-conversion representation while detecting changes in any component. Keep the fixture vector and single advance unchanged, and prevent a refused work admission from entering actor advance at all.
