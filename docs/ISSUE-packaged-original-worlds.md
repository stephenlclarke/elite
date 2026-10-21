# Packaging verifier omits copied original-world resources

SwiftPM copies `Resources/OriginalWorlds` as a directory. The current built resource bundle contains the original-world catalogue, authoring data and provenance at their exact nested paths with source-identical bytes. The packaging verifier instead classifies this copied directory as processed resources and searches for each basename at the bundle root, rejecting a correct app bundle.

Add the original-world directory to the existing copied-path policy. Preserve exact bytes, missing-resource rejection and flattened-alias rejection in both supported SwiftPM bundle layouts. Do not weaken signing, notarization, source checkpoint or resource verification.
