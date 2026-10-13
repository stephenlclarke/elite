# Consistent native screens, ship comparison and reliable targeting

Player reports identify misaligned laser mount labels, oversized System Data text, and R failing to centre ships or engage actual station docking. Requested extensions are a docked read-only showroom retaining all ship data, an eight-galaxy map browser, and a secret PLUGH discount port in every galaxy.

Acceptance: use the existing compact bitmap font at a fixed logical size across native screens and full screen; pair four mount labels with their actual fittings and shared click geometry; expose every retained canonical ship with source-labelled specifications, genuine models where available, unavailable states elsewhere, linked rotation and pinned/current-fit comparison. Browsing must freeze simulation and preserve commander state. Galaxy previews must never travel or replace live fuel/market/route state. PLUGH requires per-galaxy saved discovery, actual travel/docking and consistent paid discounts without defeating equipment limits.

R must visibly centre the selected ship, clear stale steering and engage full station guidance at Docking tier or higher. Remove C docking while keeping route clearing and showroom comparison. Preserve the approved app icon, original 256 systems, historical mission rules, existing saves and independently maintained research. Run native visual checks, regression tests, coverage, sanitizers and leaks; publish authoritative Sonar analysis only from committed main.

Implementation: [PR-5.md](PR-5.md).

Pull request: <https://github.com/stephenlclarke/elite/pull/5>.
