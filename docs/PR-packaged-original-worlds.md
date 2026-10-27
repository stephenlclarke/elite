# fix(distribution): verify original worlds at their copied paths

The bundle verifier now treats `OriginalWorlds` like the existing copied ship, mission, script and texture directories. App construction already copies the complete SwiftPM resource bundle, so no runtime content or bundle generation changes.

The existing resource fixtures now include the original-world catalogue and provenance. Their valid flat/nested bundle cases failed before the fix and pass after it. Missing files, changed bytes and a root-level alias replacing a nested original-world catalogue remain rejected. Four Python unit methods cover both layouts without launching the game, a Swift build or notarization.

Production Swift, fonts, mission code and test gates are unchanged by this packaging correction. Actual signed/notarized universal packaging and extracted-resource verification remain required before distribution.
