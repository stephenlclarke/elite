# Whole-app review remediation ledger - 17 October 2026

G3 source reconciliation checkpoint: `3c510875a6152be289d89edc1b561d17a19ba413`; current composed source checkpoint: `34713f2577829be42d09d31c0b53bd1d500df3b9`. The finding rows retain that bounded source review and its historical evidence limits. This ledger is not final execution acceptance or release approval. Final composed validation remains pending for every row below.

The original review concerns `a23ffc9fa165a26ee2f00d984517423eed55e2be`: 17 confirmed findings (two P1, thirteen P2, two P3) and the separately qualified CR-10 investigation. Preserve `docs/CENTRAL-COMBINED-GATE-VALIDATION-026.md/.json` and the original review unchanged as historical evidence. The 026 gate passed before these repairs and cannot validate them.

| ID | Implemented guard or behavior in the reconciliation checkpoint | Known validation reference and limit |
| --- | --- | --- |
| CR-01 | `EliteApp.swift`: typed Commander file intents share the input FIFO and single-consumer guard; active URLs change after successful processing. | `docs/PR-ordered-native-commander-files.md` identifies three native regressions. The handoff itself is source-only; H036 is a later historical full gate, not current-head acceptance. |
| CR-02 | `CommanderCargoValidation.swift`: validate mission payload bounds before checked aggregation; `Game.swift` rejects invalid checked occupancy. | `docs/PR-save-admission-safety.md`: child-process malformed-input and rollback regressions. Handoff source-only; H036 historical. |
| CR-03 | `MissionGallery.swift`: reconcile catalogue selection by stable identity and guard detail lookup; `PackTransactions.swift` uses replacement helper. | `docs/PR-mission-economy-review.md`, slice `3ebd8a02526619724111b514f262a6a51381df3a`; handoff source-only; H036 historical. |
| CR-04 | `PackRuntime.swift`: stage energy and both shield resource fractions with the replacement Commander before publication. | Same economy handoff, slice `ace13c0196007a72e995bc4d8af7a82ecfc69a83`; real upgraded-device regression source; H036 historical. |
| CR-05 | `ECMControl.swift` owns elapsed duration; `Game.swift` advances it using admitted flight delta. | H028: actual focused pass; `docs/PR-CR-05-ecm-time.md`. Current final composed gate pending. |
| CR-06 | `AutoTargetControl.swift`: actual hull turn/roll limits and a bounded translational thrust budget, including station avoidance. | H028; `docs/PR-CR-06-autopilot-hull-limits.md`. Current final composed gate pending. |
| CR-07 | `EffectiveEquipmentValidation.swift` checks finite effective capacities/recharge/spool and representable fuel/reach calculations; `CommanderEquipment.swift` invokes it before derived admission. | `docs/PR-effective-equipment-statistics.md`: malformed fitted axes, grandfathered values and rollback regression sources. Handoff source-only; H036 historical. |
| CR-08 | `ProfitScan.swift`: exact Decimal accumulation and unsaturated ranking; `Game.routeScore`: convert operands to Double before multiplication. | `docs/PR-mission-economy-review.md`, slice `2d683988e73e9b69b7435c4befb697fc85d94b34`, and `docs/PR-route-score-overflow.md`; handoffs source-only; H036 historical. |
| CR-09 | `MiningLedger.swift`: bounded incremental decoding and invariant checks; `Commander.valid` checks optional saved ledger validity. | H028; `docs/PR-CR-09-mining-save-invariants.md`. Current final composed gate pending. |
| CR-11 | `CommanderSaveInput.swift`: inspect the opened regular file and read bounded chunks plus one sentinel byte; `GameRuntime.load` uses it. | `docs/PR-save-admission-safety.md`: sparse/growing/nonregular/FIFO and exact-limit regression sources. Handoff source-only; H036 historical. |
| CR-12 | `PackTransactions.swift`: check prospective external file count, existing ID/digest and copied bytes before installation; reinstall stays within the same limit. | Economy slice `3ebd8a02526619724111b514f262a6a51381df3a`; handoff source-only; H036 historical. |
| CR-13 | `NavigationComputer.swift`: value only sellable cargo and use it for detour eligibility, excluding marked mission firearms. | Economy slice `2d683988e73e9b69b7435c4befb697fc85d94b34`; handoff source-only; H036 historical. |
| CR-14 | `NativeShipValues.swift`: selected/pinned comparisons use actual portable-equipment transfer projection and expose incompatible fits. | `docs/PR-rendering-ui-review.md`: actual trade/projection regression sources. Handoff source-only; H036 historical. |
| CR-15 | `Display.swift`: transform finite mesh vertices before near-plane rejection; retain existing polygon/segment clipping. | Same rendering handoff: rotated/elongated near-plane regression sources. H036 historical. |
| CR-16 | `script/sonar.sh`: maintained-source guard includes untracked inputs; committed main and exact source SHA are checked before and after coverage. | H027 offline scanner tests; no authoritative analysis published by those tests. Final main-only Sonar remains separate. |
| CR-17 | `AudioPresenter.swift`: consume explicit bounded discharge events with a session epoch and cursor; consecutive positive flash snapshots no longer define emission identity. | Rendering handoff: repeated-shot/deduplication/session/tool regression sources. H036 historical; current audio/native acceptance pending. |
| CR-18 | `ChartDisplay.swift`: Clear activates only inside `searchClearRect`; outside clicks preserve the query. | Rendering handoff: inside/outside hit regression sources. H036 historical. |

## CR-10: preserve the qualification and subsequent evidence

The original unlimited-new-deaths claim remains retracted: logical and terminal NPC entries are capped at 128. It must not be reinstated as a confirmed original finding.

The distinct living-NPC cull/rebind route was subsequently reproduced. Its pre-fix regression on `de3dd4ca7fc09fb5578b61dd8621dde0885d3d35` recorded attack history growing from one through 24 entries, including after roundtrip. Raw failed log SHA256: `bd40a48bcdfe185da1387f6d331ea4cfafd02d3c6042653574fae666ce46eb27`.

The implemented repair passes only accepted living rebindings from `NPCPersistenceRuntime.swift` to `CrimeLedger.rebindActors`, reconciles current attack/threat addresses and preserves frozen launch judgement, original attribution and settled deaths. `GameplayCombat.swift` uses the resolved current offender for live legal and aggression effects. H028 and the later H028-consumer pass below are separate, overlapping evidence and must not be summed. See `docs/PR-CR-10-survivor-threat-bindings.md` for the retained failed consumer case and corrected report-kind oracle. Current composed regression and full-gate acceptance remain pending.

## Historical evidence register

- **H026:** clean source `4cf39004374c0d253b955a5150b7b2d5589ddebc`, runtime-equivalent to original review `a23ffc9...`; 840 tests per lane, 95.08% coverage, sanitizers and zero leaks. These repairs were absent. Records: `docs/CENTRAL-COMBINED-GATE-VALIDATION-026.md/.json`.
- **H027:** real offline Sonar-entry-point guard tests: nine methods passed; no real scan published. `docs/PR-review-source-guard.md`; `/tmp/elite-review-source-guard-027/controlled-result.json`. The first fixture attempt remains failed historical evidence.
- **H028:** `6a60631e606289bb579d351eea208c05242fd238`; 125 focused methods in 14 suites passed in 21.353 seconds. Log SHA256 `93c11ee65c1612b0d5f4f1a9a59ea59466bd2de38e0bb31ca5ec837e0ff06f3c`. Covers the simulation repair regressions and compatibility focus; no current final-head inference.
- **H028-consumer:** `39085f1ffa4b96463ff7c58e612369a33854c64b`; 55 methods in seven suites passed in 8.360 seconds, including the real delayed-impact consumer/current-legal-cap tests. Log SHA256 `e7d591143e74de3db6c34c553f7cd50f329646d16d6e555b62a95acf65c65a1b`. Overlaps H028; never add their counts.
- **H030:** `217d5a4341af1aa53b384b91d33552b3bb6767ba`; 78 pure focused methods passed. `/tmp/elite-g2-canonical-focused-030/root-verification-030.json`; raw log SHA256 `a6c1411271a042d1239901e6567eef02f6c8f00d67f201c38088df46376cae4b`. Not native, mission-composition or full-CI acceptance.
- **H036:** `d29d64bc0cdeda934e352d4f9fb1ad7167c374e3`; local full gate: 898 tests per lane, 95.1615767% line coverage, zero leaks, 237 original native artifact hashes verified. `/tmp/elite-native-window-fixture-036/root-full-ci-verification-036.json`; log SHA256 `63913c408f7163cfb294d5aeaa070b833fc9800cf6510bd41b10e4d70aa0506f`. Later current composition is different source; this is not its full gate.
- **Hosted d955:** PR head `d955b1e73409f750f0ff20366a77edee96f62c5f`, merge `ed7c210f816ebcdb18fa146b9b31d6e7cf22e8f7`, same tracked bytes. Run `38976299873`: 899 tests in each lane and zero leaks, `make ci` exited 0, wrapper exited 125 for residual-process closure. `/tmp/elite-pr20-d955-quality-failure-verification.json`. The overall check remains failed; the old process state was not recorded and must not be called live or zombie from assumption.

## Separate current acceptance work

Native ARC window ownership (`3c510875...`), native reset persistence (`01beab8...`, test corrections `af131898...` / `93992ab...`), bundled G02 discovery and mission stack/lifetime work are separate current changes, not retroactive modifications to the original review findings. Current numbered compile, focused test and failure records must be attached by the central integrator before final closure. A discovery count is not an executed-test count; a source refactor is not proof of a stack fix. Local stack exhaustion is distinct from the earlier hosted Objective-C sanitizer crash.

Release acceptance still requires the final composed maintained gate, original native artifacts, sanitizer/leak and process closure, actual final-head independent review, required hosted checks, renderer-generated media where changed, and committed-main exact-SHA Sonar publication. Do not waive failed checkpoints or transfer historical results to a different source. Root/G1 owns maintained-document reconciliation and publication after the actual gates. This source-stage reconciliation preserves the original review and historical evidence files unchanged.

## Current composed evidence and unresolved failures

The following entries are separate checkpoints. Their selected or passed counts overlap and must not be added. A method pass marker within a parameterized test does not cancel a failed parameter case. Discovery, compilation, focused execution, full gates, publication and original-engine parity remain distinct.

| Checkpoint | Actual result | Current interpretation |
| --- | --- | --- |
| 047, 055, 064, 079 | Historical compile/discovery checkpoints | Catalogue sizes identify discovered tests, not executed passes. The 062 compilation failure remains retained; the later comment-type correction does not change its result. |
| 048-052, 056-060, 063, 065-066, 069-071, 073-077, 080, 082-083, 085, 087-088 | Retained failed local checkpoints | Includes stack guard crashes, assertion failures and partial batches. Source or fixture repairs do not retroactively pass them. Original logs, results, process evidence and available attributed crash reports remain retained. |
| 054, 061, 068, 072, 078, 084, 086 | Separate focused successes after reviewed lifetime or fixture changes | Establish only the actual exercised method or methods on each recorded source. None is a final full gate or hosted-crash repair proof. |
| 067 | Four actual native window-close and reset methods passed | Real close/run-loop access, task join and reset save/rollback were exercised. This does not establish the cause of the hosted Objective-C crash. |
| 081 | Five selected courier methods passed | Includes real typed handoff routing and terminal ordering. The separate initial Contracts/Gallery stack path was addressed and exercised at 084. |
| 087 | Failed 45-method semantic selection on `f6e3d557ce8ac598d3c01d961e25d1dbd6cfdc63`; 33 completed-pass method markers, failing cases and SIGBUS | All seven bundled-pack methods completed, but contract/pledge fixture and policy issues and the pledge UI stack failure prevent acceptance of the selection. Preserve the original failure. |
| 088 | The unchanged actual pledge Market/Gallery method failed alone with SIGBUS | Independently reproduces that path; no attributed original IPS was found for this attempt. The 087 attributed IPS remains separate evidence. |
| 089 | Compile passed; three of five selected methods passed on `cd868189ed6594b692c8018fc63cf1012b4dee62`; no signal | Actual zero-hold refusal, 128-receipt budget and original Market/Gallery trial passed. The new refusal fixture's overlong name and the legacy full-Commander reload comparison failed. Their pending repairs are not accepted by this run. |
| 090 | Actual renderer generation and currentness passed for all 171 ship animations and reference outputs on `2fb73dc51b1903d300e101a2718e36d2ad1d30c7` | Original 168 animations, README media and icon bytes are unchanged; seven generated paths changed. Subsequent Markdown lint found three bare licence URLs in generated provenance. The maintained generator repair and controlled reference regeneration subsequently passed at 092; the original Markdown failure remains retained. |
| 091 | Normal compilation and all 47 selected contract/pledge/bundled methods passed on `247d4ea4554254f72905eb7fc589c24d932208ab`, with no signals | Actual selected methods all started and passed; protected save/preferences unchanged and all owned process start signatures gone. This accepts the focused semantic selection, not full CI, sanitizers, leaks, hosted crashes, review or release. |
| 092 | Controlled reference generation/currentness and actual generated Markdown lint passed on `2ef44572b64a315976cf9900af9e3537a3cf565d` | Exactly three known licence URLs became Markdown autolinks. All 171 GIF bytes remain unchanged/current; source facts and all other tracked inputs are unchanged. The resulting provenance-only commit is `7cccf02edcd2495233129807d72cff0e7df7c63c`. |
| 093 | Full `make ci` failed at the SH128 Python preservation check on `7cccf02edcd2495233129807d72cff0e7df7c63c`; original make exit 2 | Distribution 11 tests and 171-ship currentness passed; showroom 39 tests had one failure. Discovery found 1,529 identifiers but no Swift coverage, sanitizer, leak or native lane ran. The separately reviewed strict three-field preservation repair is integrated at `34713f2577829be42d09d31c0b53bd1d500df3b9`; full retry remains pending. |

The current source includes the reviewed ContractBoard scroll-helper and complete ScriptPagePresentation equality-helper changes, the explicit-save/physical-hold/receipt-budget/typed-market fixture corrections, and the newly authored typed pledge-refusal regression. The latter failed validation at 089 because its commander name exceeded the existing 16-character limit. The separately reviewed name/precondition correction and test-only coherent XYZZY setup/disk/reload correction were then integrated and both paths passed at 091. Full authoritative property comparisons remain, including exact persisted and reloaded Commander equality; no production guard was waived. The original 089 failures remain failed historical evidence.

The policy-only test/doc change at `2fb73dc51b1903d300e101a2718e36d2ad1d30c7` preserves exact greater-than-Int32 Food preview and resource checks while requiring atomic refusal of the invalid final physical load. Its new real 21-tonne to 16-tonne donation regression distinguishes valid final fitting from blanket rejection of an overfilled start. Both changed tests subsequently passed in the actual 091 semantic selection. No production fitting guard changed. The mission owner's adapter documents retain ownership of this detailed policy.

The [local evidence index](WHOLE-APP-REMEDIATION-EVIDENCE.json) records the 37 available Root game-test verification files discovered for this snapshot, with exact file hashes and original statuses. It is a bounded index, not a complete inventory of every historical compile, full gate or hosted artifact. The indexed paths are local retained evidence locations, not portable published artifacts. Their presence does not replace final maintained evidence; the coordinator must attach final actual CI/media records before publication.

### Hosted failures remain separate

- The original PR #19 `a804f245c4baf3668b22393206a43a048465739a` ASan failure in run `38948765618` remains unresolved. The Objective-C `objc_msgSend` crash is not established as the same cause as any later local stack failure, and no matching original IPS was available for that attempt.
- Hosted d955 remains failed overall as recorded above: original make exit zero did not satisfy wrapper process closure. Its missing historical process state must not be invented.
- Historical PR #20 abc7 run `38985239506` failed Thread Sanitizer with SIGABRT/BUS in Objective-C/Foundation/run-loop frames and no project frame or classified data-race report. Coverage completed with 899 tests and 95.134943% line coverage; ASan and leak gates were not reached. Original make exit 2 and wrapper exit 2 remain failed. Its owned residual process was recorded across the bounded observation and cleaned up; no matching IPS was found.
- The separate abc7 native probe run `38985239512` passed one focused method. Its 24 JSON and three PNG originals and process closure do not convert the failed full quality run into a pass or prove zero leaks. The one-off probe workflow/script/test are excluded from current source; only the maintained quality capture was imported.

### Review and distribution remain pending

A requested Codex review on tap PR #9 and the historical PR #20 review returned `An unknown error occurred`. These are incomplete service responses, not clean reviews or approvals. The user requires actual `@codex review`, completed results, fixes and repeated review until clean, plus final-head required checks before every merge. Existing branch protections remain unchanged; tap #9 additionally requires CODEOWNER approval. No administrator bypass is authorized by a failed review service response.

Daily dependency configuration, current full-SHA Node 24 action pins, read-only dependency review and maintained hosted failure evidence are source-integrated at `cd868189ed6594b692c8018fc63cf1012b4dee62`. They are not deployed to main in this snapshot. GitHub release 1.4.0 and published Homebrew 1.3.1 refer to earlier distribution checkpoints. Elite PR #16 and tap PR #9 retain ownership of cask synchronization. The current composed game has not been published by this work. No successful CodeQL scan or vulnerability-free status is claimed.

## Current licensing and reference formatting

The source-only notice repair at `247d4ea4554254f72905eb7fc589c24d932208ab` records the parsed 171-model distribution: 59 CC-BY-NC-SA-3.0, 14 CC-BY-NC-SA-4.0, one CC-BY-SA-3.0, three author-declared public-domain models and 94 MIT project interpretations. The 77 imported models retain their own terms. SH168/SH169/SH170 retain full Commies original README/manifest custody in their unchanged TOMLs; existing source packaging copies those complete resources and verifies bytes. No licence was invented or changed, and this source audit does not claim a newly built distribution package.

The separately reviewed maintained reference-generator formatting fix was integrated at `2ef44572b64a315976cf9900af9e3537a3cf565d`. Its pure all-171 reference comparison changes only the three existing bare licence URLs into Markdown autolinks, leaving source facts, punctuation, catalogue text and GIF input/output fingerprints unchanged. The coordinator then ran actual canonical reference generation/currentness and both generated Markdown checks at 092; all passed. The generated provenance-only output was committed at `7cccf02edcd2495233129807d72cff0e7df7c63c`. The original failing lint output/status remains retained as failed historical evidence with this subsequent resolution.

## Undelivered RRS/P30 station prerequisite

RRS/P30 remains undelivered. The source contains no accepted genuine RRS station registry/population/docking/service boundary for P30 scenario 2. A research packet, a plan, a station name or an alias of the main orbital station does not make it playable.

The reviewed prerequisite plan requires distinct persistent waystation and headquarters identities with checked source geometry, placement and entrance/exit; actual docking selection and launch from that same station; saved docking/service receipts and lifecycle tombstones; explicit market/equipment/auto-trade capability gates; and real native authority supplied to the mission board. Preserve the existing main-orbital G02 contract semantics. Research identifies 364 waystations and eight headquarters, including separate waystation and HQ actors in HQ systems; these are source requirements, not implemented population counts.

MC1 can implement the actual scenario-2 board, unique protected packet, acceptance, original living main-station debrief and atomic terminal counters/payment only after that native boundary is implemented and validated. Other P30 families remain queued according to the [mission implementation queue](MISSION-IMPLEMENTATION.md). The generic contract system and bundled G02 courier do not satisfy this prerequisite. This ledger does not edit the separately owned research catalogue or declare the game or mission backlog complete.

## Final evidence to attach before closure

| Acceptance item | Status in this snapshot |
| --- | --- |
| Reviewed fixture corrections and all 47 focused semantic methods | Passed at 091 on its exact source; broader full gates remain pending |
| Actual renderer-generated 171-ship media/catalogue/provenance and README media | Generation/hash currentness passed at 090; subsequent three-link reference repair/currentness/Markdown lint passed at 092 |
| Final composed `make ci`: coverage, TSan, ASan, leaks, native originals and process closure | Pending; no historical full gate is transferred |
| Final-head completed clean PR review and required hosted checks | Pending; reviewer service errors remain failures to complete review |
| Committed-main Sonar analysis with exact commit SHA and Previous version policy | Pending |
| Distribution, signing/notarization checks and synchronized reviewed tap update for the resulting release | Pending |
| Genuine native RRS/P30 prerequisite and scenario-2 delivery | Not implemented; must remain explicitly open |

The coordinator will append actual final source SHA, gate/media artifact identities, raw hashes, review/check results and publication state before committing the final reconciliation. Until then, this is an honest source/evidence ledger, not a completion certificate.
