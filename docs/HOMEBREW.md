# Homebrew distribution

Install the signed, notarized universal macOS app with `brew install --cask stephenlclarke/tap/elite`, then launch it with `open -a Elite`. It requires macOS 14 or later and supports Apple silicon and Intel. Quit the game before upgrading; use `brew update` followed by `brew upgrade --cask stephenlclarke/tap/elite`. `brew uninstall --cask elite` removes the application while preserving `~/.xyzzy/elite/`, including your commander and installed mission packs. The cask has no save-removal or quarantine-bypass hooks.

The source of the cask is [Casks/elite.rb](../Casks/elite.rb); its published tap copy is [stephenlclarke/homebrew-tap](https://github.com/stephenlclarke/homebrew-tap/blob/main/Casks/elite.rb). The download uses an immutable commit containing the actual tracked ZIP, rather than assuming a GitHub Release exists. That asset commit differs from the executable's source checkpoint, which is recorded in the release manifest and app bundle.

## Release synchronization

First complete the [signed/notarized packaging workflow](MACOS-DISTRIBUTION.md), merge the archive and companion manifest through protected main, and fetch the published main. Only then update the repo and isolated tap copies from that release's manifest:

```sh
make homebrew-cask ELITE_HOMEBREW_VERSION=1.3.1 ELITE_HOMEBREW_COMMIT=1ef005e0c73971a360a0e3bb52792a9286a761d3 ELITE_HOMEBREW_TAP=/path/to/homebrew-tap
make homebrew-cask-check
```

Replace both version and asset commit for a future release. Synchronization checks that the asset commit is on fetched `origin/main`, reads its committed manifest/ZIP, verifies size/checksum, requires both architectures, macOS compatibility, Developer ID signing, hardened runtime, secure timestamp, notarization and Gatekeeper acceptance, and verifies the public download before writing. It refuses a branch label or an unpublished source-only checkpoint. `--check --verify-download` also checks public availability without writing. Review and publish the two repository changes through their normal protected PR checks.

The tap's narrowly scoped cask workflow checks Ruby syntax, style, strict online audit, isolated install/uninstall, signature, stapled ticket, Gatekeeper and quarantine. Homebrew 7's `Cask/Url` rule mistakes this tracked binary ZIP's `/releases/macos/` path on `raw.githubusercontent.com` for a GitHub-generated source zipball. Only that rule is excluded for this cask's style invocation; the pinned URL is verified by the archive hash, strict audit and install checks. No inline RuboCop suppression or trust-policy workaround is shipped.

Native Apple-silicon installation and removal were verified in an isolated application directory without launching or replacing a user's app. Both executable architectures and their macOS deployment targets were inspected. Native Intel and physical Sonoma gameplay are not claimed by these installer checks.
