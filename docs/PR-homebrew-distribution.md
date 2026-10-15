# Maintain Homebrew installation of the signed app

## Motivation and implementation

Add the maintained Elite cask, safe installation/update/removal documentation, and manifest-based synchronization for the owner's tap. The current cask pins the already public 1.3.1 universal ZIP at asset commit `1ef005e0c73971a360a0e3bb52792a9286a761d3` with SHA256 `2452a5a486b6b772c323a6c0647e9c217a9c7c55e0fe4f2df768073bc1541ad2`. This asset commit differs from its embedded source checkpoint. The synchronizer verifies committed main ancestry, manifest trust properties, both architectures, archive size/checksum and public availability before writing. `make homebrew-cask-check` joins the existing CI with inexpensive deterministic metadata/guard checks.

See [ISSUE-homebrew-distribution.md](ISSUE-homebrew-distribution.md) and the companion [tap PR #7](https://github.com/stephenlclarke/homebrew-tap/pull/7). Its separate cask workflow leaves the existing formula workflow unchanged and tests actual isolated installation/removal. Homebrew's raw-binary URL false positive is narrowly documented; quarantine and saves remain intact.

## Validation

The committed/public ZIP matches the 7,970,167-byte manifest/checksum. Ruby syntax, strict online/both-architecture cask audits, signature, stapled ticket, Gatekeeper, quarantine and isolated install/uninstall checks pass. Tap hosted Elite Cask and required Formula Syntax checks pass at `6c7021c72b0c686c8a265f2e8a6fe3ef477581d4`. The repo/tap copies are identical. Synchronizer guard tests, check-only/public-download validation, Markdown lint and diff hygiene pass. The protected Elite PR runs complete `make ci`; no earlier runtime SHA is presented as evidence for this later branch.

## Compatibility and remaining gates

Requires macOS 14 or later; arm64 and x86_64 are included. No game mechanics, save schema, ship data or mission engine changes. Native Intel and physical Sonoma execution were not performed. Tap publication still requires its existing separate approving review; this change does not bypass or weaken it. Sonar remains main-only with the exact committed SHA.
