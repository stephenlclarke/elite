# Physical native quality runner

The required `quality` check runs the complete `make ci` pipeline on the physical Apple Silicon Mac. The existing `elite-ci` runner stays inside its isolated VM for the maintained unit selection. Neither the VM label nor its guard is changed. The native renderer tests require a real Metal device, eight-sample rendering and a command queue; CPU fallback or a skipped hardware assertion does not qualify this check.

## Authorization and source

The physical runner uses the separate `elite-native` label and dedicated `~/Library/Application Support/EliteCI/native-runner` checkout. It registers ephemerally, listens for one job and unregisters after that job. No persistent service is installed. Only the repository owner's internal reviewed PR, main push or explicit branch dispatch is accepted. Forks, another actor, a different workflow/job, another head, forced main pushes and deleted branches fail closed.

Workflow routing is not the security boundary. Before registration, `Tools/CI/prepare_native_runner.py` copies the reviewed guard outside both the runner application and checkout, and writes an owned read-only policy pinning the exact approved head and compiler/SDK identities. The runner's own `.env` installs its pre-job hook. The hook validates immutable event metadata before any workflow step or checkout and publishes an exact-head attestation. A rejected hook fails the job; `continue-on-error` cannot override it. [GitHub's pre-job hook contract](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/run-scripts) describes this ordering and failure behavior.

The workflow also routes untrusted events to a hosted runner and fails before checkout. Such failures or missing physical capacity remain failed or pending quality checks; they never count as a qualified pass. Checkout has read-only repository permissions and does not persist credentials. A second check validates the actual assigned checkout and confines the incremental cache to the dedicated owned workspace. The original required check name, coverage threshold, unfiltered tests, sanitizers, leak check and committed-main-only SonarQube analysis remain intact.

## Preparing one approved job

Use the reviewed clean commit and the verified SHA-256 of the official macOS ARM64 Actions runner release archive. Preparation requires Python 3.12 or later for safe archive extraction. Registration obtains a short-lived token through the existing authenticated `gh` session, captures configuration output without printing credentials, and passes no secret through the public workflow.

```sh
python3.12 Tools/CI/prepare_native_runner.py \
  --approved-head "$APPROVED_ELITE_HEAD" \
  --runner-archive "$VERIFIED_RUNNER_ARCHIVE" \
  --archive-sha256 "$VERIFIED_RUNNER_ARCHIVE_SHA256" \
  --register --run
```

Set repository variable `ELITE_NATIVE_RUNNER_ENABLED=true` only after the reviewed setup is ready. Use a source policy and ephemeral registration for each approved PR/main checkpoint. A prepare-only invocation can be followed by registration at the same approved head. Setup creates missing trust folders privately and rejects symlinks or group/world-writable trust folders. Reuse requires identical owned, immutable guard, hook and policy bytes, permissions and toolchain identities; the read-only installation marker is verified without being rewritten. Every installed archive file and link is checked against the verified archive before reuse; an ownership marker or recorded archive digest alone is insufficient. Preserve a previous registered runner instead of overwriting its active configuration. The source policy and guard are outside the checkout and cannot be removed by its clean step.

Keep the console session available for the existing AppKit window and actual-renderer assertions. Capability is established by those unchanged hard tests in the affected batch and full required run, not by hardware labels. Retain the exact source, toolchain, selector, XML when produced, terminal log, timing, GPU result and runtime diagnostics. A failure or unavailable capability remains a blocker.
