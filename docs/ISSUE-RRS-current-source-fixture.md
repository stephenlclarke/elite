# RRS fixture requires a current two-kind station source

CI934 on `485fab55293ca984e38b3c88659e3712a601b12b` throws `invalidState` from the shared launch fixture before the malformed-save owner, duplicate and adapter cases run. G01-S237 is now Anarchy and declares headquarters only, contradicting the fixture's two-station requirement.

Use current G04-S149 (Lolodor, Democracy), which declares one headquarters and one waystation. Preserve real launch, both station-kind cases and all save-forgery/rollback assertions. No production, default hull/fuel, geometry or source-placement policy change is needed.

Owner MC1, through Root. Isolated base `bac6e79a9b386d30bae55959536013a7e8fca2be`. Source prepared; focused execution and independent review remain pending. G1's fatal-capture CPU hold prevents build/test execution until Root returns the slot.
