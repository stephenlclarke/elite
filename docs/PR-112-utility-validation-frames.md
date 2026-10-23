# fix(runtime): separate absent utility classification from present job validation

Rescue acceptance must run the full utility policy without reserving present
utility-job payloads while classifying unrelated missions. Keep the existing
job filter/count and reverse parent receipts, then dispatch each marked job to
its original complete guard body in a separate non-inlined reader. Marking keeps
definition, digest and optional-leaf presence in the same short-circuit order,
using a presence pattern rather than a by-value nil-comparison argument.

Every present utility source/owner/authorization/time/actor/receipt check remains;
no rescue assertion, state, codec or stack limit changes. Strict Swift formatting,
Markdown and whitespace pass. Independent actual patch review and one changed-head
execution of the original two methods/seven cases remain pending. No broader
M01 journey, full suite or release pass is claimed.

The next captured parent-receipt closure reserves a large crew-log capture for
unrelated missions. Keep parent iteration and absence decisions in the common
reader, then enter a separate non-inlined reader only for an actual parent
crew-log claim. Preserve exact capture/job equality and rescue-reception joins,
with the same left-to-right refusal order. No parent claim is ignored or trusted
without the original complete matching source check.

Address the captured path coherently: keep ark classification, cardinalities,
parent ordering, expected-job set equality and job ordering in the common
reader, while present-parent and complete present-job guards run in separate
non-inlined frames. Presence classifiers keep the same identity/leaf rules.
All ark recovery/link/receipt/time/actor/fuel checks remain in their original
order. No unrelated validator family or state representation changes.

The shared event validator now receives the staged candidate and its Commander
through explicit inout access to the existing _modify storage projection. Its
helper only reads the unchanged Commander.valid policy; it never changes the
Commander, escapes, calls a publisher or suspends. This avoids the proven owned
computed-read argument before the deep validation walk. The candidate is already
actor-owned and exclusively staged; Array COW and rollback value semantics stay
intact. The borrow ends before error-message projection or publication.
