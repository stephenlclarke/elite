# test(profit): prove integer bounds with authentic market witnesses

## Implementation and independent evidence

The bounded source-only witness pass uses authenticated G01 market and world bytes, without native execution, RNG rerolls, repricing or outcome-based selection. The tests initialize actual SH025 context at fixed original-world IDs, retain every authored ask and bid, and zero only mutable stock for held-cargo valuation. All quantities remain nonnegative and at most `Int.max / 17`; Gold and Platinum use their actual kilogram units. Every case requires a valid Commander before evaluating profit.

G01-S000 to S016 has exact Gold/Platinum bid differences 184 and 801. Fixed nonnegative integer quantities independently produce `Int.max - 1`, `Int.max`, and `Int.max + 1`; reversing the same quotes produces `Int.min`, `Int.min + 1` and a value below `Int.min`. The raw integers are pinned as decimal strings, so no overflowing Int or floating-point conversion constructs the oracle.

G01-S000 to S020 has bid differences -1242 and 815. Pinned quantities and the reversed market direction each cancel to exactly ten, with both opposing individual terms exceeding the Int presentation bounds. Both original Boolean term-order arguments remain.

At G01-S003, a maximal admitted Gold hold gives distinct scores for reachable S116 and S038: 503487602953013643616 and 495891884805015592958. Both display as `Int.max`, while ordering must retain the larger full score. A smaller authentic hold of 947 Gold and 472 Platinum gives exactly 1526400 at both S084 and S116, requiring stable ascending-ID order. All three destinations lie within the actual nine-LY native reach. Repeated ranking preserves both Commander and market in each phase.

The prospective-export witness buys Food at S001's actual ask 129 and values it at S168's bid 261. With the existing unlimited-cash flag, the actual Int affordability bound permits 71499008037633920 units; their 132-unit spread gives 9437869060967677440, exceeding `Int.max`. Only the admitted stock quantity changes; both quotes remain authentic.

## Validation and remaining work

Strict Swift formatting, scoped Markdown lint and whitespace checks pass. Source-only integer arithmetic and quote checks bind the witness packet and its authenticated input hashes. These are author prerequisites, not runtime qualification. The existing four methods and five cases require one focused owner run and independent coherent review; no pass is retained for the changed helper consumers. No build, test or native probe ran during authoring.

Exactly one test file and these paired notes change. There is no production seam, framework, catalogue/default/quote/economy edit, removed validity assertion or relaxed numerical bound. G1 owns shared qualification and integration; final CI, sanitizer, leak and release acceptance remain separate. No remote PR exists. Companion: [ISSUE-profit-authentic-market-witnesses.md](ISSUE-profit-authentic-market-witnesses.md).

## Compile correction after candidate 967

The owner build stopped after 8.191 seconds because Swift Testing's macro type checker could not resolve the two inline tie-arithmetic requirements. No profit test ran. Extract each unchanged arithmetic expression into an explicitly typed `Int` local before requiring equality to `1_526_400`. Every literal, independent oracle and production-result assertion remains intact. The original compile failure is retained under `/tmp/elite-profit-compile-967`; the corrected child still requires matching compilation and the four-method/five-case owner run. No author build, test or native probe ran.

## Qualification update - 20 October 2026

The corrected child passed matching969 compilation and actual970four methods/five cases, including both opposing order arguments, with zero issues or unknown outcomes. Source,1925 real immutable artifacts and preferences stayed exact; all owned processes closed. The original967 compilation failure before tests remains preserved. One original coherent CLEAN review plus the focused compiler-only typed-local delta CLEAN review were retained. Exact reviewed3paths integrate at`908f197e2488f3118b605145f7bba381a263bdc5`; this documentation child records the later outcome. Evidence: `/tmp/elite-profit-corrected-970/event-stream-qualification.json` and `/tmp/elite-profit-qualified-canonical-integration/integration-receipt.json`. Generated codecov outputs alone are excluded from immutable snapshots; no broader CI, global coverage, sanitizer, leak or release qualification is implied.
