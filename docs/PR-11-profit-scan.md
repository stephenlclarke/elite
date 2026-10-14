# Automatic profit scan

Delivered together in [PR #11](https://github.com/stephenlclarke/elite/pull/11). See [the integrated validation and release evidence](PR-11.md) and [request checklist](DELIVERY-BACKLOG.md).

Adds a saved P toggle to charts and navigation, enabled automatically by XYZZY. Current-galaxy chart markers highlight ranks 1-5; navigation details report conservative profit estimates or no profitable destinations.

Estimates compare sellable carried cargo with local sale value and add available affordable exports, respecting market stock and storage. Reserved mission payloads are excluded. Fuel costs and risk are explicitly outside the estimate. Scanning does not mutate cargo, cash, route or destination. Old saves default off.

Validation: five focused Swift tests pass; the 228-test coverage run passes at 92.95% overall Swift coverage. Markdown lint and diff whitespace checks pass. `make ci` stops at ships-check because all source-fingerprinted GIFs need regeneration; no media were modified in this slice. Sanitizer/leak gates were started separately and combined integration gates remain the main coder responsibility. No external publication or Sonar analysis is performed from this worktree.

Related issue: ISSUE-11-profit-scan.md. Integration must retain the small chart marker additions while merging chart layout work.
