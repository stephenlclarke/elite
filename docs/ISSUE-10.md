# Issue for PR #10: notarize the signed macOS download

The signed 1.2.0 universal download has a valid Developer ID signature and hardened runtime, but originally lacked Apple's notarization ticket and was rejected by Gatekeeper as `Unnotarized Developer ID`. The shared container release credentials returned Apple HTTP 401. The owner's replacement `APPLE_NOTARIZATION` local secret is accepted and can authorize Elite's submission without committing credentials.

Notarize the existing signed package, staple Apple's ticket and verify the final extracted ZIP. Preserve the executable, resources, signature, version and original source checkpoint. Publish the updated checksum, actual acceptance evidence and accurate player/operator documentation. Keep existing saves, ship definitions, research and gameplay unchanged.

Acceptance: Apple reports `Accepted` with no issues; both executable architectures are covered; strict nested signature, stapled-ticket validation, exact-resource comparison, diagnostic launch and Gatekeeper assessment pass. Run `make ci`; respect the required GitHub quality check and publish SonarQube only from the committed main SHA. See [PR-10.md](PR-10.md).
