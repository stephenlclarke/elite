# Preserve copied resource directories during package verification

Preview packaging 1215 stopped because the maintained verifier expected OriginalFleetShowroomModels/SH084.json at the bundle root. Package.swift copies that directory intact. OriginalShipTextures and OriginalMarkets were also absent from the verifier's copied-directory policy. The actual staged nested file matched the source; this was a checker defect, not evidence of a missing app resource.

Keep all eight copied resource directories in their SwiftPM locations in either supported macOS bundle layout. Processed legal/licence files retain their existing flattened layout. Missing files, altered bytes and flattened aliases must remain failures. A manifest contract test must detect future divergence between the maintained copy policy and Package.swift.

Scope is package_macos.py, its existing unit tests and these paired notes. No build, signing, notarization, archive or app behaviour changes. This correction does not resolve the separate GitHub review service error or establish full release acceptance.
