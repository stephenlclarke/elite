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
