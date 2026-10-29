# Bound the maintained universal Release build scheduling

The maintained macOS packager starts `swift build --configuration release` for arm64 and x86_64 without the serial/nonbatch compiler controls already used by bounded build paths. Its CLI has no build-argument override. A separate prebuild cannot change the packager's own subsequent invocation.

Append `--jobs 1 -Xswiftc -disable-batch-mode` to the existing shared build vector. The build and its `--show-bin-path` query must use the same configuration, scratch path, architectures and scheduling options. Preserve the release-plan, committed-source, resource, signing, notarization and artifact checks.

Scope is the existing packager, the existing fake release test seam and this note pair. This is a compiler scheduling correction, not an RSS or hard-deadline guarantee. It does not establish a Release-specific resource authority, authorize a build or change any resource cap. G1 owns integration after the current quality attempt reaches its terminal outcome; independent review and all required release gates remain pending.
