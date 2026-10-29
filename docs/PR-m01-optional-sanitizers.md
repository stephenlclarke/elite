# fix(ci): restore optional unpartitioned local sanitizers

## Result

`make threads` and `make address` run the original full-suite Swift sanitizer commands directly. `make sanitizers` runs thread then address, including under parallel Make, and stops on failure. `make threads-full` aliases `threads`. Default `make ci` and hosted CI leave sanitizers off; `ELITE_SANITIZERS=1 make ci` runs both after the normal required checks complete. The normal coverage, leak and static checks remain required. See [problem and requirements](ISSUE-m01-optional-sanitizers.md) and [PR232](https://github.com/stephenlclarke/elite/pull/232).

Standalone targets require no shard controller, policies, checkpoints, counters or local-proof bridge. They use the local Swift toolchain and separate scratch paths. Thread concurrency stays as the original command; address retains `--no-parallel` and disables ASan leak detection because macOS leaks remains a separate gate. No filters or assertion changes are introduced. Historical controller implementation and evidence remain available to their existing consumers.

## Validation and limits

Seven passing focused interface tests exercise the actual Make targets with a fake Swift executable, including exact argument/environment preservation, combined sequencing, nonzero failure propagation and the compatibility alias. Default and opt-in CI dry runs check that required checks remain and sanitizer commands appear only after explicit opt-in. Two existing required-workflow contract tests also pass, along with scoped Markdown lint and diff checks. No Swift build, sanitizer run, hosted quality pass or release is established by these interface checks. Another Mac needs Xcode selected and its normal package toolchain available; its actual full-suite sanitizer outcome remains to be measured there.
