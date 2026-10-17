# Recursive PLUGH fixture reserves purchase buffers at each prerequisite depth

The full thread-sanitized catalogue's debugger stopped during the original PLUGH supported-item shop test's real equipment purchase. Its stack contains five nested buyPlughPrerequisites frames. Exact binary inspection found one Game-sized and two Commander-sized buffers reserved in every helper frame before its recursive call, although their purchase and verification reads happen after recursion returns.

Keep the original graph traversal, prerequisite lookups, foundation skips, paid-history semantics and real purchase checks. Reserve only the purchase step's buffers after child traversal has returned. No production purchase rule or test outcome should change. See [implementation](PR-plugh-prerequisite-lifetimes.md).
