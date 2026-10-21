# Contract board summary compiler timeout

[Issue #35](https://github.com/stephenlclarke/elite/issues/35) records a Swift type-check timeout in `ContractBoardDisplay.swift` at the `preferredSummary` expression. Hosted [run 39671764452](https://github.com/stephenlclarke/elite/actions/runs/39671764452/job/119471181557) failed to compile source head `84c733dea8c5d3da8d5a50ae6b5779b53e69b46b` before isolated units ran.

The expression combines a row reason with several optional row-kind summaries. Split those fallbacks into sequential assignments to the existing typed `String?` local. Each later fallback runs only when the earlier result is nil. Keep the exact row-kind guards, priority and displayed strings. The remaining RRS/courier and pledge/offer/unavailable fallbacks stay unchanged.

Scope is this expression only. No gameplay, save, authority, diagnostic suppression or unit-selection change is needed. The next existing hosted run must confirm compilation and execute the maintained 74 pure units; local source checks alone do not prove that the compiler timeout is resolved.
