# Station system-coordinate projection repair

## Motivation

[Issue149](https://github.com/stephenlclarke/elite/issues/149) records an actual mapped stack guard fault in the original physical station evasion test. Reading two stored coordinates through a whole Commander pointee creates an outlined Commander copy.

## Implementation

Add one noninline addressable-scalar SystemIdentity reader in Game.swift. Reuse it in the full validation policy and identical native body-current, population-header and physical-adoption projections. Each pointer stays inside the original synchronous storage borrow. Complete policy order and every gameplay predicate remain unchanged; repeated system reads remain repeated reads.

## Validation

Swift formatting and diff hygiene are checked before the focused original four-method/twelve-case selection. Focused execution and independent actual-diff review are pending. No new selector, assertion weakening, stack-size change or test concurrency change is introduced.

## Compatibility and remaining limits

No save schema, authority, state ownership, actor boundary or player behavior changes. The previous b53 VM failure remains retained. The final full VM and required quality checks must qualify the corrected head separately; focused local results do not establish native M01 or release acceptance. See [the issue evidence](ISSUE-149-station-system-projection.md).

At source d7e292a3df27c8dfbbf70be5baff70fb60ee77f7, all four original methods and twelve cases passed under local Swift Testing 6.4.1 on arm64, with complete XML and zero failures, errors or skips. Compilation took 214.31 seconds; total process duration was 229.775552 seconds. The original physical evasion method completed in 9.524 seconds, mesh/refusals in 8.874 seconds, five storage/default cases in 8.905 seconds and five lazy-policy cases in 0.074 seconds. Evidence: `/tmp/elite-149-system-projection-units-result.json`, its raw log and `-swift-testing.xml`.

Independent review cleared the exact source and execution evidence and closed issue149 on this affected criterion. This does not establish a full VM, required quality, native M01 or release pass; issue144 remains separate. No repeat execution is needed for documentation-only composition.
