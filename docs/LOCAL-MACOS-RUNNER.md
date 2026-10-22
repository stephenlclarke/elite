# Local macOS unit runner

The local runner runs the existing `isolated-units` GitHub job inside an isolated macOS VM on the MBP. It keeps the same `make unit-ci` command, three Swift jobs, coverage instrumentation, exact-commit reports and selected tests. It does not replace final release quality, signing, notarization or clean-main SonarQube checks.

## Routing and isolation

The repository variable `ELITE_LOCAL_RUNNER_ENABLED=true` selects the local runner only for `push` events in `stephenlclarke/elite` made by Stephen's account ID `22142777`. Pull requests, including fork pull requests, remain on `macos-15`. An absent or false variable keeps the hosted route. The local preflight independently rejects other events, repositories, actors and forks.

The runner is dedicated to this repository and has labels `self-hosted`, `macOS`, `ARM64`, `elite-ci`. Run only one runner process. Use the isolated VM without shared host directories, personal credentials, SSH agents or signing keys. Review workflow changes before approving external contributions: repository routing expressions are configuration, not a security boundary against a deliberately modified workflow. Do not route external code to the VM.

The VM uses macOS Sequoia and Xcode 16.4. Local preflight requires an Apple Silicon `VirtualMac`, Apple Swift 6.1.2 (`swiftlang-6.1.2.1.2 clang-1700.0.13.5`) and macOS SDK 15.5. It fails rather than silently switching compiler versions.

## Persistent build cache

The checkout's `.build` stays a physical directory inside the guest workspace. This preserves the existing crash collector's strict path-confinement checks. The local checkout skips the action's blanket cleanup; verified local preflight runs `git clean -ffdx -e /.build/` to remove other untracked or ignored inputs. Tracked files still come from the action's forced checkout. Failed jobs retain compiled objects too; there is no dependency on a successful cache-upload post-step.

The fingerprint includes the full Swift version, SDK, architecture, package manifest/resolution and the existing three-job coverage mode. Source changes use SwiftPM's normal incremental dependency tracking. The runner writes an explicit ownership/fingerprint marker inside `.build`. A changed fingerprint clears only this owned disposable cache. A foreign directory, malformed identity, file or symlink is preserved and rejected rather than deleted.

The cache stays inside the VM. Do not point it at a developer's `.build`, share it with untrusted jobs, copy it between compilers, or change stack sizes or test selection to make the local job pass.

## Operation

1. Provision and boot the pinned VM, with no host directory mounts. Keep its runner credentials inside the guest.
2. Verify `swift --version`, the SDK and VM identity, then confirm GitHub lists the dedicated runner as online and idle.
3. Enable `ELITE_LOCAL_RUNNER_ENABLED`. Existing jobs already assigned to hosted runners continue there; do not duplicate them.
4. Use the next required source push for the first local qualification. Record queue, compile and execution durations from its existing logs, source SHA, toolchain fingerprint and reported case counts. A first cold build is not an incremental-build benchmark.
5. Let the MBA review the same GitHub results. Authors retain responsibility for remediation and protected merges.

Coordinate VM compiler activity with the local compiler lease. The developer can continue source work while the one runner compiles; do not start competing local Swift compiler or native performance jobs. The VM's initial image download and provisioning are one-time setup costs and do not count as feature-delivery time saved.

Set `ELITE_LOCAL_RUNNER_ENABLED=false` before stopping the runner. New pushes then use hosted macOS again. Do not leave the variable true with the only matching runner offline, because trusted pushes would queue indefinitely. Preserve already-running jobs and their evidence.

## Validation and limits

`make local-runner-check` checks rejected events/actors/forks, incompatible build inputs, wrong machine/compiler/SDK rejection, removal of stale source inputs, physical-cache survival across checkout cleanup and compatibility with the existing crash collector's confinement function. It also checks that foreign data is preserved and only an owned incompatible cache is rebuilt. Run `actionlint .github/workflows/unit-tests.yml` after routing changes.

These checks prove the routing/cache helper's boundaries. A usable runner also requires actual VM boot, registration, an online GitHub state and a completed exact-head job. Do not claim a speedup from setup checks or compare a warm local compile with an unrelated cold hosted build.
