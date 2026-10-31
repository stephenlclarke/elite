# fix(media): refresh Redtail and Besra gallery outputs

## Change

The existing native renderer regenerated all 171 gallery ships from PR298 source `bc1aae3c`. Only `SH103.gif`, `SH108.gif`, the shared manifest and `overview.png` changed. The other 169 GIFs are byte-identical. The overview changed only within the Redtail Mk III and Besra tiles; all other decoded pixels remain identical. No game source, hull data, README tape or release artifact changed.

This resolves the stale renderer fingerprints described in [the issue](ISSUE-m04-ship-media-freshness.md). The manifest records actual rendered output, rather than a manual freshness refresh.

## Validation

- One `make ships` invocation passed in 218.174 seconds, including the actual 182.15-second build. All 171 ships rendered; none were reused.
- One `make ships-check` invocation passed in 3.747 seconds.
- Every GIF retains a 256 by 256 canvas, 24 frames, 0.10-second frame delay, infinite loop and its original container transparency facts. All fresh input and output hashes reconcile.
- The overview retains its 2560 by 4608 dimensions. Only its two changed hull tiles differ.
- All 4,267 tracked entries outside the corrected 175-output scope retain their modes, types and blobs. All 59 historical session states remain unchanged.
- Independent actual-output review `29c3ac35` cleared the terminal result, freshness, two hull images and corrected overview scope. The original scope omission and unsupported opacity assertion remain recorded as collection findings.

The existing single-worker, non-batch, 2.25-GiB renderer guard, two-hour deadline, output bound, shared leases, custody check and live admission remained unchanged. No automatic rerender, cache reset, guard waiver or consumed-session replay occurred.

## Remaining qualification

The failed native attempt did not execute the game normal suite, the ten new hull cases, coverage or leak checks. A separate hosted isolated workflow succeeded on the original bc1aae3c source and reported 569 tests passed; its XML inventory has not been independently reconciled here. That older result does not qualify this newer media recovery commit. The final-head isolated selection still needs its actual workflow result. A new committed source and PR execution binding need independent review and a fresh finite native authorization. PR success must then be followed by actual-main qualification and main-only Sonar analysis. Visual gallery output does not establish physical flight, docking or full M04 acceptance.
