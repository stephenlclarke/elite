# feat(fleet): compile the complete indexed original hull delivery

## Result

Tools/compile-original-fleet.py accepts --fleet-index as a safe relative path beneath --input-root. It joins the exact expected SH001..SH171 set to the supplied statsFile and effective geometryFile paths. Absolute author workspace metadata is descriptive only. The first 28 new hulls therefore use the delivery's approved native LOD fragments, while their detailed designs and all 171 specifications remain unchanged.

## Implementation

The existing record compiler is shared by directory and indexed input. Indexed mode validates its schema, unique complete IDs, expected hull count, matching spec and geometry filenames, safe symlink-free paths and exact lowercase SHA256 fingerprints. Raw hulls, nativeDesign, detailed design, source specs and all authored fields remain intact. Readiness records retain the actual source geometry path and delivery-index fingerprint. One parsed hull is resident at a time; existing input/output budgets and fresh-output behavior apply. No guessed scale, balance, policy, fallback hull, runtime catalogue or compatibility migration is introduced.

## Usage

Run from a repository containing the tool, with a fresh output directory:

```sh
python3 Tools/compile-original-fleet.py --input-root /path/to/delivery-workspace --fleet-index fleet-completion-20261019/delivery-index.json --output-root /path/to/fresh-staging --expected-specs 171 --expected-hulls 171
```

The existing --check mode checks frozen staged payloads. Existing typed-definition and reference exporters accept this staging tree unchanged. The game renderer, native collision/unit mapping and live catalogue integration remain separate work.

## Validation

On SteveMBA, the changed compiler's 16 focused/existing Python tests passed in 0.207 seconds, including five new indexed-import methods. They cover effective LOD selection, exact source provenance, stale spec/hull fingerprints, missing/duplicate/mismatched IDs, unsafe paths/symlinks and deterministic staged output/check mode. One actual complete 171-input staging pass succeeded in 52.363 seconds; typed definitions and reference generation then succeeded in 0.164 and 0.125 seconds. These are source-tool timings, not game performance measurements. No Swift compiler, native application, GUI, profiler or full CI job ran on the MBA.

All 171 generated records remain runtimeReady=false. Actual ship rendering, collision/query budgets, fitting/purchase policy and player/NPC fleet activation are unverified by this change. Central integration, required project CI and PR review remain outstanding. No GitHub issue or PR has been created for this leaf.

See the [source gap](ISSUE-original-fleet-delivery-index.md).
