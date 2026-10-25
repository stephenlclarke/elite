# M02: structural application identity still names Elite

The existing runtime title, application window and branding use L337. The package and executable product still use Elite, and both development and release packaging generate Elite.app with the previous bundle display name and identifier. A label-only correction cannot make that built product consistent.

Root approved the exact 19-file package/executable mapping recorded in the M02 naming assessment, then the necessary twentieth file: the showroom media tool's executable-product argument. This packet retains EliteCore, EliteMac and EliteCoreTests as module/target names, while changing the package and executable product to L337. Their generated resource bundle therefore becomes L337_EliteCore.bundle; all eight native bundle fallback lookups must match. The test image observers must recognize L337PackageTests without weakening their ownership checks.

No storage/content directory, module/import/source-path migration, repository/CI guard, runner naming, provenance-key, generated icon/media, published download or Homebrew cask change is included. Legal attribution and historical releases remain intact. These are explicitly deferred naming gaps, rather than claims that the full L337 migration is complete. Native integration, signing, installation and release qualification remain M01-first work.
