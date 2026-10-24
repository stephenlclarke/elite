# Align showroom tests with the original Peregrine Mk V

Three historical assertions still expect the superseded SH025 recipe and cargo delta. Replace that expectation with the approved complete SH025 source hash and explicit name, family, profile, current cargo values and absence of a generated recipe. Recipe totals now account for exactly that one authored hull.

The other historical whole-record and 74 source-geometry pins remain intact. No game definitions, historical fixtures, media, generator or fingerprint rules change.

Validation: only the three failed methods were selected; all three PASS in 11.019s. Frozen two-file delta and actual output: `/tmp/elite-showroom-baseline-933`. CI932 passed flight/distribution/media gates and stopped at showroom-check; mission validation, coverage, sanitizers and leaks have not yet run. Independent delta review precedes commit and resumed CI. See the [issue](ISSUE-showroom-original-hull-baseline.md).
