# Homebrew distribution

[L337 1.6.0 is available as a signed, notarized direct download](../README.md#download-l337-160-directly). Its [maintained L337 cask](../Casks/l337.rb) pins the same published universal ZIP and source commit. The published Homebrew tap installs historical Elite 1.5.1 after its [reviewed update](https://github.com/stephenlclarke/homebrew-tap/pull/10) merged. Adding a cask here does not publish it to the tap. Use the direct download for L337 until its separate tap update passes review and merges. Historical Elite plans and casks remain separate from new L337 release numbering.

Install the signed, notarized universal macOS app with `brew install --cask stephenlclarke/tap/elite`, then launch it with `open -a Elite`. It requires macOS 14 or later and supports Apple silicon and Intel. Quit the game before upgrading; use `brew update` followed by `brew upgrade --cask stephenlclarke/tap/elite`. `brew uninstall --cask stephenlclarke/tap/elite` removes the application while preserving `~/.xyzzy/elite/`, including your commander and installed mission packs. The cask has no save-removal or quarantine-bypass hooks.

The historical Elite cask is [Casks/elite.rb](../Casks/elite.rb); its published tap copy is [stephenlclarke/homebrew-tap](https://github.com/stephenlclarke/homebrew-tap/blob/main/Casks/elite.rb). New cask versions use the signed archive and manifest from an actual [GitHub Release](https://github.com/stephenlclarke/elite/releases/latest). The Source commit comment identifies the exact main source pinned by that release tag. Historical Artifact commit/raw-archive casks remain checkable against their original retained evidence; they are not inputs for new release numbering.

## New L337 release synchronization

First complete the [automated signed/notarized release workflow](MACOS-DISTRIBUTION.md), including publication. Reuse its authoritative generated plan; do not choose a separate Homebrew version or artifact commit:

```sh
make homebrew-cask ELITE_HOMEBREW_TAP=/path/to/homebrew-tap
make homebrew-cask-check
```

The synchronizer verifies that the public plan equals the generated plan, its exact source/history and release tag agree, and its signing manifest binds the same version/source/plan. It requires both architectures, macOS compatibility, Developer ID signing, hardened runtime, secure timestamp, notarization and Gatekeeper acceptance. The public ZIP's exact size and SHA-256 are verified before writing new `Casks/l337.rb` repo/tap copies. The historical Elite cask is not overwritten; no tap-repository rename is implied. Missing, draft, unpublished, mismatched or manually versioned updates refuse. `--check --verify-download` also checks availability without writing. The cask and tap updates still need their normal requested review and required checks before merging.

The tap's narrowly scoped cask workflow checks Ruby syntax, full cask style, strict online audit, isolated install/uninstall, signature, stapled ticket, Gatekeeper and quarantine. The GitHub Release asset URL allows the full style checks; the earlier raw-GitHub URL exception is removed. No trust-policy workaround is shipped.

Native Apple-silicon installation and removal were verified in an isolated application directory without launching or replacing a user's app. Both executable architectures and their macOS deployment targets were inspected. Native Intel and physical Sonoma gameplay are not claimed by these installer checks.
