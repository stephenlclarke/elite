# Qualify M01's preserved normal result after a bookkeeping-only fix

## Result

The root fallback `default.profraw` is ignored. The normal phase can consume one explicitly installed, immutable host authorization for the preserved PR 232 run. It writes a separate `attested-from-prior-execution` receipt with old tested and current qualified revisions, zero new test execution, both original/current identities and policies, reviewed blob deltas and original output hashes. It exports verified coverage without copying the original passing receipt into a newly labelled completed attempt. The aggregate job and other quality phases retain their independent requirements.

## Implementation

`m01_normal_attestation.py` pins the original approved/tested revisions, result hash, policy hash and attempt location. Its host-owned authorization file lives beside the current exact-head native policy, outside the checkout. The operator installs it only after independent review of the frozen delta. It binds the actual current approved commit/tree and exact old/new hashes for the narrowly enumerated bookkeeping files, including the validator and hook themselves. All other tracked executable/dependency inputs and execution identity fields must match. Only the approved-head and policy-path environment hashes may change, and both must bind immutable policies whose contents differ solely in their actual approved head. Current native event/actor/workflow/source/physical-host authorization is checked again.

The original result and every output are rehashed and passed through the existing full XML, source-bound opt-in, runtime diagnostic and coverage validators. Current source cleanliness and executable-image guards remain in force before export. Missing authorization leaves ordinary exact-identity cache behavior intact. An installed but invalid authorization fails closed; it never silently triggers a replacement normal run.

## Validation and limits

Fake evidence with real Git exercises explicit old/new provenance, unchanged immutable receipts, zero repeated execution, ordinary cache inequality, changed runtime/dependency/selection/image/compiler/SDK/opt-in/environment rejection, exact reviewed tool hashes, dirty/source-tree rejection, authorization-policy drift, tampered output and writable trust-file rejection. The real-Git profile regression fails with the ignore removed and passes when restored; tracked/untracked source and nested profiles remain rejected. These tests launch no compiler or game process. The original saved normal result retains its actual revision and 90.47633943583769% coverage; no sanitizer, leak, final-head aggregate or release success is implied by this change.
