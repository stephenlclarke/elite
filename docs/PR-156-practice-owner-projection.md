# Read practice owner without whole Commander projection

## Motivation

[Issue156](https://github.com/stephenlclarke/elite/issues/156) attributes the current VM mapped-guard fault to the practice owner lookup in the original station-evasion test.

## Implementation

A noninline Game storage bridge projects only the actual stored equipment owner UUID, with original nil semantics. The practice owner helper first finishes the unchanged shallow body eligibility in a separate noninline borrowed-body phase, then performs that owner read. Complete payload/reservation/native-save policies are unchanged; no mission label grants authority.

## Validation

Formatting and diff hygiene pass. The original authentic entry, five active-hazard arguments and authentic-versus-forged membership method retain their existing assertions and selectors (three methods/seven cases). Focused execution and independent review are pending. [The issue evidence](ISSUE-156-practice-owner-projection.md) records exact current image, fault, guard and above-guard SP distinction.

## Compatibility and remaining limits

No save schema, state mutation, actor ownership or player behavior changes. No synthetic passed aggregate, historical signal attribution or151 reopening. Final full VM, required quality, signing and release remain separate; no broad native or performance campaign is started.

At exact74bf5eca2c072ff4432ba1e1f9e0eaba8aab9988, all three original methods/seven cases passed with process exit0, complete XML and zero failures/errors/skips. Original authentic entry/evasion9.487s, five active-hazard cases9.351s and reservation membership8.726s; compile193.74s/total209.023129s under local Swift Testing6.4.1 arm64. Evidence `/tmp/elite-156-practice-owner-units-result.json`, raw log and `-swift-testing.xml`. Independent source review cleared the exact typed owner and eligibility phase change; independent actual-source/result verification closed156 on this affected scope. Full VM/required quality and release remain separate. No unchanged focused rerun, new test selector, media or package is required for documentation composition.
