# Signed macOS distribution

`make package-macos` builds a Release executable for Apple silicon and Intel, assembles `Elite.app`, copies the exact runtime ship/mission TOMLs and legal notices, signs with Developer ID Application, enables the hardened runtime and requests Apple's secure timestamp. The resulting ZIP, SHA256 and manifest are tracked under `releases/macos/`.

Commit and validate the source before packaging. The manifest and bundle identify that exact source checkpoint; the later commit that adds the binary is not falsely described as its own build source. No private signing keys or notarization credentials belong in Git. Set `ELITE_SIGNING_IDENTITY` to use another valid Developer ID Application identity. The default identity is the project owner's certificate.

If a configured notarytool keychain profile is available, set `ELITE_NOTARY_PROFILE` before packaging. The workflow submits the signed ZIP, waits for Apple's decision, staples and validates the ticket, then requires Gatekeeper acceptance. Without a configured profile it still creates and validates the signed package, recording `notarized: false` and the actual Gatekeeper result. Developer ID signing and notarization are separate states; inspect the supplied manifest before distribution.

Validation operates on the extracted ZIP: strict signature and nested-code checks, Developer ID authority/runtime/timestamp, both executable architectures, byte-identical runtime resources and a diagnostic launch. A notarized build also validates its stapled ticket. The package does not claim an Intel native UI playthrough when built on Apple silicon.

Download the ZIP from `releases/macos/`, verify its companion SHA256, extract it and move `Elite.app` to Applications. It requires macOS 14 or later. A signed build without notarization can be rejected by Gatekeeper on another Mac; the manifest reports that limitation rather than claiming normal downloaded-app approval. The local `make run` workflow remains a separate ad hoc signed debug build.
