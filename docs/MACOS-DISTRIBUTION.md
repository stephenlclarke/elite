# Signed macOS distribution

New releases use one generated plan. On the exact clean, reviewed and quality-qualified protected-main source, `make release-plan` selects the highest actually published stable ancestor tag and calculates SemVer from all reachable non-merge Conventional Commits since that tag: `!` or a `BREAKING CHANGE:`/`BREAKING-CHANGE:` footer makes a major release, `feat` a minor release, and `fix`/`perf` a patch. The highest impact wins once per release. Other types, including documentation and chores, do not release by themselves. Invalid non-merge headers and existing calculated tags refuse. Actual merge commits are excluded to avoid counting their child commits twice; squash commits count as their actual conventional header/footer. Use Conventional Commit PR titles and merge subjects, preserving declared breaking changes. Existing history and published tags are not rewritten.

The plan records the exact source, published base tag/commit, complete classified commit inventory and its SHA-256. Packaging validates those recorded inputs rather than independently choosing a version. A branch-only `--preview` can show the calculation but cannot package or publish. Historical release tags may identify later artifact/documentation commits, as recorded below; new tags identify the exact protected-main executable source. SonarQube analysis remains separate and uses the exact main commit SHA, not the app's SemVer.

```sh
make release-plan
ELITE_NOTARY_PROFILE=elite-release make package-macos
make publish-release
make release-readme
make homebrew-cask ELITE_HOMEBREW_TAP=/path/to/homebrew-tap
```

Keep the generated `dist/release-plan.json` for this whole sequence. `make release` combines plan generation, packaging and publication; it does not merge a PR or waive quality/review gates. Do not pass a manually chosen version. The app bundle, ZIP names, checksum, signing manifest, release tag, README links and cask all consume the same plan. M01 is released first; M02 receives a new plan from its own actual history after M01 is public.

`make package-macos` builds a Release executable for Apple silicon and Intel, assembles `Elite.app`, copies exact runtime resources and legal notices, signs with Developer ID Application, enables the hardened runtime and requests Apple's secure timestamp. New artifacts are written to ignored `dist/macos/`; existing historical tracked downloads remain intact. The bundle and signing manifest identify the plan's exact source commit, and the manifest binds the plan's SHA-256. No private signing keys or notarization credentials belong in Git. Set `ELITE_SIGNING_IDENTITY` to use another valid Developer ID Application identity.

Publication requires the exact current main source's successful quality/main-analysis check, verified signatures/notarization/Gatekeeper manifest, matching archive/checksum/plan and Apple's Accepted report. It creates the source-pinned tag and a draft, verifies every uploaded asset's identity, size and server SHA-256, then publishes. Partial failures leave no successful-publication receipt; matching drafts can resume without overwriting existing assets. README and Homebrew updates require the actual published tag and verified artifacts, and still go through the normal review/merge process. The authoritative plan is not regenerated for those consumers.

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
