# Homebrew distribution

Install the signed, notarized universal macOS app with `brew install --cask stephenlclarke/tap/elite`, then launch it with `open -a Elite`. It requires macOS 14 or later and supports Apple silicon and Intel. Quit the game before upgrading; use `brew update` followed by `brew upgrade --cask stephenlclarke/tap/elite`. `brew uninstall --cask stephenlclarke/tap/elite` removes the application while preserving `~/.xyzzy/elite/`, including your commander and installed mission packs. The cask has no save-removal or quarantine-bypass hooks.

The source of the cask is [Casks/elite.rb](../Casks/elite.rb); its published tap copy is [stephenlclarke/homebrew-tap](https://github.com/stephenlclarke/homebrew-tap/blob/main/Casks/elite.rb). New cask versions download the versioned ZIP from an actual [GitHub Release](https://github.com/stephenlclarke/elite/releases/latest), with its exact SHA-256. An artifact-commit comment retains the protected-main provenance of the tracked ZIP and manifest. That commit differs from the executable's source checkpoint, which is recorded in the release manifest and app bundle. The checker also understands the previous immutable raw-GitHub cask so the migration does not alter an older trusted download.

## Release synchronization

First complete the [signed/notarized packaging workflow](MACOS-DISTRIBUTION.md), merge the archive and companion manifest through protected main, fetch the published main, then create its versioned GitHub Release and attach the ZIP, checksum, manifest and Apple report. Only then update the repo and isolated tap copies from that release's manifest:

```sh
make homebrew-cask ELITE_HOMEBREW_VERSION=1.4.0 ELITE_HOMEBREW_COMMIT=bba862c558530ea2d40d634f84fbd490d9cc3401 ELITE_HOMEBREW_TAP=/path/to/homebrew-tap
make homebrew-cask-check
```

The example targets the published 1.4.0 artifact. Replace both version and exact 40-character protected-main asset commit for a future release. Synchronization checks that the asset commit is on fetched `origin/main`, reads its committed manifest/ZIP, verifies size/checksum, requires both architectures, macOS compatibility, Developer ID signing, hardened runtime, secure timestamp, notarization and Gatekeeper acceptance, and verifies the public download before writing. It refuses a branch label or an unpublished source-only checkpoint. `--check --verify-download` also checks public availability without writing. Review and publish the two repository changes through their normal protected PR checks.

The tap's narrowly scoped cask workflow checks Ruby syntax, full cask style, strict online audit, isolated install/uninstall, signature, stapled ticket, Gatekeeper and quarantine. The GitHub Release asset URL allows the full style checks; the earlier raw-GitHub URL exception is removed. No trust-policy workaround is shipped.

Native Apple-silicon installation and removal were verified in an isolated application directory without launching or replacing a user's app. Both executable architectures and their macOS deployment targets were inspected. Native Intel and physical Sonoma gameplay are not claimed by these installer checks.
