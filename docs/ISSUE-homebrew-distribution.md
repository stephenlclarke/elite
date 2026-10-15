# Install the published app through Homebrew

## Motivation

The game has a signed, notarized universal download but no maintained cask or repeatable synchronization from its release manifest. The user requested Homebrew installation of the current published GitHub binary, with safe upgrades/removal and preserved commander data.

## Acceptance

Maintain `Casks/elite.rb`, pin the commit containing the actual public ZIP and its SHA256, preserve quarantine and `~/.xyzzy/elite/`, document installation/updates/removal, and synchronize the owner's tap from verified committed manifests. Do not invent GitHub Release URLs, install from source, target a future binary, or weaken trust/branch protections. Validate the installer in an isolated application directory. The published tap implementation is tracked in [tap PR #7](https://github.com/stephenlclarke/homebrew-tap/pull/7).
