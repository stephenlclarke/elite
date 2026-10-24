# feat(missions): expose the Original repair-loop service

## Behavior

Offer the full Cedamar-to-Celalen-to-Cedamar repair loop on the existing station board. Show the original failed serial, two-tonne protected transport loan, registered workshop, original owner and 610 CR settlement. The player separately confirms pickup, actual workshop repair and owner return. No deposit, fee or hidden deadline applies; finite source units never replenish.

## Implementation

A typed W02 board adapter uses native source, issue, service and return authority. The same unit remains transport-only before and after repair. Native service changes its physical condition and creates the exact receipt required by original-owner return. Native settlement closes the equipment obligation and protected payload, pays once and grants only the exact production repair-loop clue. Default pack discovery preserves installed ordering and identical-content deduplication.

G3 authors the twelve UI/pack/tests/documentation paths, G2 the twelve native paths, and G1 the three central Game/save paths. Owner runtime qualification uses G1's combined isolated source. No MC1 branch import or overlapping central authorship is included.

## Validation

Owner qualification passed on combined source `ff3a131cf88a6b8aa0a197835d79f4873bdf2bf9`: all sixteen selected methods and seventeen cases in one run, across seven native methods, three board/player methods and six affected bundled-default methods (seven cases). The test run passed in 61.395 seconds; bounded supervision completed in 66.468 seconds with no timeout, cleanup or remaining owned processes. Source files, preferences and test binary remained unchanged. Matching build passed in 484.58 seconds under the existing cache, flags and default worker stack/concurrency.

Native flows cover six predeclared failed serials, transport-only permissions and hull transfer, actual workshop repair and original-owner return, writer rollback, current normal/Alien saves and corrupt claims, mixed W01/W02 shared capacity, real escape and measured fatal-hit loss with retry. UI flows cover Back/redock/load/stale confirmation and actual two-unit service/return with the exact production clue once. The six directly affected bundled-default methods cover discovery, deduplication, distinct installed content, malformed content, trial and saved-provider restore. Unaffected tests were not repeated.

Native CLI validation accepted exact production digest `c0b674ac2eca0221890412446f423c5f7ada4520b38669dbfbef5289049c199f` on `ec155995fc13482680621f52481a893208d5fbf4`. That evidence is retained because the later causal correction changes only two native Swift files; pack bytes and declaration validation are identical.

Earlier attempts remain explicit failures: two native compile failures, then a 600-second build timeout with completed owned cleanup. One unchanged cached continuation built successfully. Its test process then crashed before any case completed; all cases from that run were unknown. The matched native report identifies stack exhaustion in the new W02 save validator during actual board pickup. The causal native correction uses immutable receipt leaves, sequential borrowed validator phases and mutation helpers that return before full postvalidation; it preserves receipt fields and authority checks. The final passing run uses the same selection and default runtime limits. The independent full twenty-seven-file bugs/performance/style review is CLEAN on tested source ff3a131c, with no findings; receipt `/tmp/elite-root-W02-independent-review.json` SHA256 `90d538bafa55a5fb86e24fa92bc125f1d7886b02b43a555275c3e58953d1aac2`.

## Compatibility and remaining work

Current normal/Alien formats 37/38 compose with existing W01 claims. Historical compatibility is not a deliverable. Approved artwork is not rendered by this text board. Broader CI, coverage, sanitizer/leak, playable delivery and release gates remain with the integrator. No remote PR or merge is claimed. Companion: [ISSUE-original-repair-loop.md](ISSUE-original-repair-loop.md).
