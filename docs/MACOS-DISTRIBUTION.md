# Signed macOS distribution

`make package-macos` builds a Release executable for Apple silicon and Intel, assembles `Elite.app`, copies the exact runtime ship/mission TOMLs and legal notices, signs with Developer ID Application, enables the hardened runtime and requests Apple's secure timestamp. The resulting ZIP, SHA256 and manifest are tracked under `releases/macos/`.

Commit and validate the source before packaging. The manifest and bundle identify that exact source checkpoint; the later commit that adds the binary is not falsely described as its own build source. No private signing keys or notarization credentials belong in Git. Set `ELITE_SIGNING_IDENTITY` to use another valid Developer ID Application identity. The default identity is the project owner's certificate.

If a configured notarytool keychain profile is available, set `ELITE_NOTARY_PROFILE` before packaging. The workflow submits the signed ZIP, waits for Apple's decision, staples and validates the ticket, then requires Gatekeeper acceptance. Without a configured profile it still creates and validates the signed package, recording `notarized: false` and the actual Gatekeeper result. Developer ID signing and notarization are separate states; inspect the supplied manifest before distribution.

On the release Mac, the validated profile is `elite-release`. Its Apple account, team and app-specific password come from local secret files `APPLE_ID`, `DEVELOPER_TEAM_ID` and `APPLE_NOTARIZATION` under `~/.secrets/`; their contents remain outside Git and logs. Configure the profile securely before running a new committed build:

```sh
ELITE_NOTARY_PROFILE=elite-release make package-macos
```

Version 1.4.0 adds graphical route alternatives and is built from committed checkpoint `36fa5cfef1e781f68dcb1fdbf7dae1e1e1f76224`. Apple accepted submission `9b09fe5e-0e67-4b2b-93fa-1c89e086bb04` with no issues; its [Apple log](../releases/macos/Elite-1.4.0-universal-notarization.json), [manifest](../releases/macos/Elite-1.4.0-universal.json) and [checksum](../releases/macos/Elite-1.4.0-universal.sha256) accompany the stapled 8,005,780-byte ZIP. Both executable slices target macOS 14.0. Extracted signatures, exact runtime resources, stapler, Gatekeeper and `syspolicy_check distribution` pass. Native Apple-silicon checks of the signed app verify the exact title/source identity, four Cobra route choices on both chart projections, local continuation, Back preserving next Reorte and Set changing next stop to Diso. The separate development-build checks cover 512/768-point layouts, pointer selection and saved-plan preservation. Pending-jump cancellation is regression-tested; the signed native attempt was mass locked and is not claimed as countdown evidence.

Version 1.3.1 includes the display-condition cleanup and is built from committed checkpoint `7d008650a7842e7e6dbd3ad84b8f38770f55c285`. Apple accepted submission `cce96571-0b9e-4156-a3c6-5be656791cfc` with no issues; its [Apple log](../releases/macos/Elite-1.3.1-universal-notarization.json), [manifest](../releases/macos/Elite-1.3.1-universal.json) and [checksum](../releases/macos/Elite-1.3.1-universal.sha256) accompany the stapled 7,970,167-byte ZIP. Both executable slices target macOS 14.0. Extracted signatures, stapler, Gatekeeper and `syspolicy_check distribution` pass. Native Apple-silicon checks verify its exact version/source identity, continued Liberator commander, compact docked chart and front/rear celestial bearings.

Version 1.3.0 is built from committed checkpoint `5939431bc038c7a099ddee9b7bb2e3ffa7567553`. Apple accepted submission `9f48657c-eae8-400f-9940-9c7e0c0ef9e7` with no issues; the [Apple log](../releases/macos/Elite-1.3.0-universal-notarization.json), [manifest](../releases/macos/Elite-1.3.0-universal.json) and [checksum](../releases/macos/Elite-1.3.0-universal.sha256) accompany the stapled 7,970,163-byte ZIP. Both executable slices target macOS 14.0. The extracted app passes strict signatures, stapler, Gatekeeper and `syspolicy_check distribution`; native Apple-silicon checks confirm the 1.3.0 title/exact SHA, continued saved commander, 512-point chart notices, contextual station help and combined celestial/station HUD.

The tracked 1.2.0 download was notarized after its original signed build, using Apple's supported preexisting-software workflow. Submission `fb6ded2b-0e06-4009-b0f8-34387a613b5f` was accepted with no issues for the app, its nested resource bundle and both executable architectures. The [Apple log](../releases/macos/Elite-1.2.0-universal-notarization.json) identifies the original submitted archive SHA256; the [manifest](../releases/macos/Elite-1.2.0-universal.json) and [checksum](../releases/macos/Elite-1.2.0-universal.sha256) identify the final ZIP containing the stapled app. The original executable, bundle metadata, runtime resources, signature and source checkpoint `402f42db4c36bd6eac5691d98ad1901944f2bf7e` are preserved. The later artifact commit records notarization without claiming a new game build.

Validation operates on the extracted ZIP: strict signature and nested-code checks, Developer ID authority/runtime/timestamp, both executable architectures, byte-identical runtime resources and a diagnostic launch. A notarized build also validates its stapled ticket. The package does not claim an Intel native UI playthrough when built on Apple silicon.

Download the ZIP from the [latest GitHub Release](https://github.com/stephenlclarke/elite/releases/latest), verify its companion SHA256, extract it and move `Elite.app` to Applications. The published [1.4.0 archive](https://github.com/stephenlclarke/elite/releases/download/v1.4.0/Elite-1.4.0-universal.zip) is byte-identical to its tracked repository artifact; the release also supplies the checksum, manifest and Apple report. The release tag identifies the later artifact/documentation checkpoint; `sourceRevision` records the executable build source. It requires macOS 14 or later. The current 1.4.0 download passes Gatekeeper as `Notarized Developer ID`. To verify an extracted copy locally, run:

```sh
codesign --verify --strict --deep --verbose=2 /path/to/Elite.app
xcrun stapler validate /path/to/Elite.app
spctl --assess --type execute --verbose=2 /path/to/Elite.app
```

The local `make run` workflow remains a separate ad hoc signed debug build.

After the ZIP and manifest are published on protected main, synchronize and validate the maintained Homebrew cask and the owner's tap using the [Homebrew release instructions](HOMEBREW.md). The cask always targets an already public, signed/notarized archive and retains quarantine and player saves.
