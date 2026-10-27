# Use an authenticated courier offer for contact routing

The contact-routing test used fresh SH025 at origin 7 and pinned row 1, whose actual frozen itinerary lower bound 729986.9574960005 seconds exceeds its 172800-second deadline. Native acceptance correctly refuses that unavailable listing. The initial caller fixture now uses the existing authenticated CourierNativeFixture.rows[1] witness at origin 0 with SH023, whose lower bound is 35798.30051999994 seconds. The shared fixture and all quote, deadline, resource, contact routing, custody, save and replay checks remain unchanged. No route reroll or deadline relaxation is introduced.

## Validation

The sole existing typedCourierBackClearsPresentationAndOnlyTheReopenedContactCanDeliver method is affected: one method and one case.

MBA source formatting and strict lint pass. The inverse source check restores the entire old test file exactly, so every pre-existing test body after the initial fixture remains intact. ASCII, exact copied hashes, Markdown lint, diff and scope checks are required at freeze. The original evidence reconciliation matches retained source hashes; the pinned courier witness preserves native acceptance constraints. No author native job or new geometry experiment runs.

G1 owns matching compilation and native qualification. One independent review of the combined six test and note paths follows actual 15-method, 17-case PASS. These fixture corrections do not establish a successful hosted CI run or account for unknown failures after the original crash.
