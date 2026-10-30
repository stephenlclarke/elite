# Homebrew distribution

The commands below install the actual historical Elite release. No L337 cask is published by this source-only rename. Existing `Casks/elite.rb` remains unchanged. Until a genuine new cask exists, `make homebrew-cask-check` uses the closed Elite 1.5 receipt/cask verifier; it does not generate a cask or select another historical source. New publication remains strictly L337 and cannot consume that historical plan.

Install the signed, notarized universal macOS app with `brew install --cask stephenlclarke/tap/elite`, then launch it with `open -a Elite`. It requires macOS 14 or later and supports Apple silicon and Intel. Quit the game before upgrading; use `brew update` followed by `brew upgrade --cask stephenlclarke/tap/elite`. `brew uninstall --cask stephenlclarke/tap/elite` removes the application while preserving `~/.xyzzy/elite/`, including your commander and installed mission packs. The cask has no save-removal or quarantine-bypass hooks.

The source of the cask is [Casks/elite.rb](../Casks/elite.rb); its published tap copy is [stephenlclarke/homebrew-tap](https://github.com/stephenlclarke/homebrew-tap/blob/main/Casks/elite.rb). New cask versions use the signed archive and manifest from an actual [GitHub Release](https://github.com/stephenlclarke/elite/releases/latest). The Source commit comment identifies the exact main source pinned by that release tag. Historical Artifact commit/raw-archive casks remain checkable against their original retained evidence; they are not inputs for new release numbering.

## New L337 release synchronization

First complete the [automated signed/notarized release workflow](MACOS-DISTRIBUTION.md), including publication. Reuse its authoritative generated plan; do not choose a separate Homebrew version or artifact commit:

```sh
make homebrew-cask ELITE_HOMEBREW_TAP=/path/to/homebrew-tap
make homebrew-cask-check
```

The synchronizer verifies that the public plan equals the generated plan, its exact source/history and release tag agree, and its signing manifest binds the same version/source/plan. It requires both architectures, macOS compatibility, Developer ID signing, hardened runtime, secure timestamp, notarization and Gatekeeper acceptance. The public ZIP's exact size and SHA-256 are verified before writing new `Casks/l337.rb` repo/tap copies. The historical Elite cask is not overwritten; no tap-repository rename is implied. Missing, draft, unpublished, mismatched or manually versioned updates refuse. `--check --verify-download` also checks availability without writing. The cask and tap updates still need their normal requested review and required checks before merging.

The tap's narrowly scoped cask workflow checks Ruby syntax, full cask style, strict online audit, isolated install/uninstall, signature, stapled ticket, Gatekeeper and quarantine. The GitHub Release asset URL allows the full style checks; the earlier raw-GitHub URL exception is removed. No trust-policy workaround is shipped.

Native Apple-silicon installation and removal were verified in an isolated application directory without launching or replacing a user's app. Both executable architectures and their macOS deployment targets were inspected. Native Intel and physical Sonoma gameplay are not claimed by these installer checks.
