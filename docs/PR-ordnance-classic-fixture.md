# Declare the classic ordnance test baseline

The current fresh starter is SH025 with 7200 credit tenths, 300 shields and 380 energy. These ordnance tests assert the classic SH023 baseline: 1000 credit tenths, 255 shields and 256 energy. The shared initial fixture now explicitly selects SH023 and its native fuel, energy and shield capacities before entering flight. Every test method body, shot path, profile, timing, actual mesh intersection, emitter ownership, legal outcome and no-credit oracle remains unchanged. All production source remains unchanged.

## Validation

All 14 existing GameplayOrdnanceTests methods and 16 declared cases are affected by the shared fixture. The two argument lists each declare two cases; internal loops are not extra cases.

MBA source formatting and strict lint pass. The inverse source check restores the entire old test file exactly, so every pre-existing test body after the initial fixture remains intact. ASCII, exact copied hashes, Markdown lint, diff and scope checks are required at freeze. The original evidence reconciliation matches retained source hashes; its independent authored SH023 face witness confirms the central-axis collision assumption for the classic fixture. No author native job or new geometry experiment runs.

G1 owns matching compilation and native qualification. One independent review of the combined six test and note paths follows actual 15-method, 17-case PASS. These fixture corrections do not establish a successful hosted CI run or account for unknown failures after the original crash.
