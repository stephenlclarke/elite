# docs: refresh ship renderer inputs after native integration

## Result

Maintained make ships regenerated all171 ships using the coherent current renderer/runtime. The only generated diff is171 input values in docs/ships/manifest.json. All GIF bytes/output hashes and catalogue/provenance tables remain identical. No maintained source, renderer policy, tests or README media changed.

The command ran in the existing warm qualification checkoutcd13e7af0af53d82440ff1ef6bfa4d32af381eb7, with byte-identical Sources/resources/Package/renderer/generator/Makefile inputs to canonical71397cf83a860db777e2c19a4025f82b4708ff0f. The actual target and its swift run arguments were unchanged. Its64.069-second execution stayed within existing600/640 limits; all68 observed actual owned starts were independently absent, no timeout/cleanup, all maintained inputs and primary preferences exact, lease1001 released.

## Validation

All4,104 frames decoded and were nonblank:171GIFs,24frames each,256x256,100ms delay, looping. Every output hash is conserved. Maintained make ships-check passes; only the manifest input fingerprints changed. Qualification `/tmp/elite-ship-media-refresh-1001/qualification.json` SHA256 `40fc2140ca0d606fa808e9b897354ac76ea6228eda71621c0eeb965dbec1298d`; renderer log SHA256 `aa7fa3af177de02d8234954d1521d6aff864fef9de349fc6709b8127e60af766`. Source-only cause receipt SHA256 `43b1c8a414ce538bd7de19e35b64bde09881ee4658fa6dcdf520ba279c65b0f5` preserves the prior hosted failure analysis.

## Delivery and limits

Update existing draft [PR21](https://github.com/stephenlclarke/elite/pull/21) by normal fast-forward push, request its required new-head review and allow hosted checks once. Prior quality39419186509 and review service failure remain retained. No local fullCI replay, protection change, feature-branch Sonar, merge, notarization, release or Homebrew update. M01 remains incomplete; G05 stays isolated. Companion: [ISSUE-ship-media-freshness.md](ISSUE-ship-media-freshness.md).
