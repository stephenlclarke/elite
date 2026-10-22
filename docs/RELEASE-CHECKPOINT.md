<!-- markdownlint-disable MD013 -->
# Development release checkpoint: 1.4.904

This is the local candidate status on 22 October 2026, not a public release announcement. Candidate 1.4.904 contains source `9106e701bb33527e564103bcc759d69cbc00ee40`, tree `5118e655f7dfb2afec0ec08655dde6a25c024fc3`. PR #25 targets main from `feature/canonical-mission-composition`.

## Evidence and limits

| Check | Actual result |
| --- | --- |
| Focused station packet | PR #94 source-qualified 342 methods / 379 expanded cases; its reviewed tree is identical to the integrated candidate tree. |
| Current-head isolated units | Both current-head isolated-unit checks passed; Dependency Review passed. These do not replace full quality acceptance. |
| Required full quality | [Run 39834119275](https://github.com/stephenlclarke/elite/actions/runs/39834119275) failed during coverage execution with a front-visibility renderer stack-guard fault, tracked in [issue #106](https://github.com/stephenlclarke/elite/issues/106). The compiled PR merge checkout was d1093408; its relevant source bytes match head 9106e701. Thread Sanitizer, Address Sanitizer and leaks were not reached; Sonar was skipped. |
| Package | Universal arm64/x86_64, macOS 14+, exact resources and extracted-package diagnostics passed. Timestamped Developer ID signature, hardened runtime, accepted notarization, staple validation and Gatekeeper assessment passed; independent delivered-artifact review passed. |
| Current save | Normal Choose Save loaded the unchanged schema39 freight snapshot created by this candidate, preserving its current assignment. |
| Freight UI journey | Real acceptance and normal hyperspace to Renas observed. Two manual approaches ended in collision and loss. Receiving, payment, clue and completed-job cold Continue are unverified. No product defect is established by these pilot outcomes. |

Archive: `Elite-1.4.904-universal.zip`, 48,431,659 bytes, SHA256 `ba50c5f074584980d9adbef8138da6474f8e9ed2e1f014f7dfc66dad9ec2bacc`. Apple accepted submission `b0b3a14b-f97d-4548-b989-4a08d63d42ea`. The local packaging manifest and log retain the build and signing receipts. They qualify this artifact only.

The copied historical schema41 checkpoint matched its hashes but normal Open rejected it. Historical development save compatibility is outside this checkpoint. No compatibility fix, grants, altered save state or synthetic receiving receipt was used. The native campaign is closed; another attempt is not implied by this document.

## M01 remains open

The remaining acceptance chain is actual original Renas main-station entry, explicit receiving of the same eight original freight units, completed assignment, once-only 730 CR settlement and one G02 first-success clue. Without other transactions, the expected balance is 1,450 CR. Save and cold Continue must retain Renas/docked status, the completed assignment, original cargo disposition, spent source history, cash and the same single clue. Reopening the receipt must not pay again. Existing component tests and simple save loading do not prove this chain.

## Gates before public release

1. Classify the terminal quality failure from its exact run and retained evidence. Repair actual blockers with meaningful focused coverage and independent review; do not repeat unchanged broad runs.
2. Bring PR #25, README, controls and the completion ledger to one agreed final head. Request `@codex review`, address actionable findings and repeat review until clean under the project's review policy. Required checks must pass for that final head before an ordinary protected merge.
3. Complete `make ci`: maintained data/control/Python checks, mission-pack validation, coverage of at least 80%, Thread Sanitizer, Address Sanitizer and the leak probe. Focused unit results do not waive these gates.
4. Analyze only clean committed main. Verify the remote Previous version new-code definition and use that exact 40-character main SHA as `sonar.projectVersion`. Confirm the actual quality gate.
5. Package the authorised public version from its exact release source. Verify universal architectures, minimum macOS, manifest, archive bytes/hash, exact resources, strict signature, timestamp, hardened runtime, notarization, staple and Gatekeeper. Local 1.4.904 evidence does not qualify a rebuilt or changed artifact.
6. Publish matching tag, release assets, manifest and checksum; verify downloaded bytes and README links. Generate any changed README media only with `make readme-media`.
7. Generate the Homebrew cask from the immutable committed manifest. Verify its version/hash, live archive, installation and security checks. The tap PR follows the same `@codex review`, repair/review, final-head checks and protected merge cycle.

Public 1.4.0 and its cask remain distinct from this development candidate. Full-window performance and every campaign's playable acceptance are not established here.
