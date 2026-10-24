# test: retain native hold capacity in freight stale-quote fixture

The freight stale-confirmation fixture now requires its original100000-unit budget without imposing an incorrect20-tonne hold on native SH023. Its existing paid market loop uses actual standardCargoCapacity and proves remaining space is smaller than the generated freight quantity before confirming the stale quote.

The test source is the exact reviewed failed648369f5 version with only the unsupported capacity conjunction removed. All quote, paid fitting and purchases, refusal, complete Commander and file rollback, and empty-instance assertions remain unchanged. Production code, shared helpers, starting resources and catalogue values are unchanged.

Source conservation, formatting and Markdown checks pass. Independent causal-delta review is clean; the single matching freight case now passes and its exact source is integrated. Whole-suite and release gates remain open. Actual1050 remains the failure record; source-only diagnosis is retained at /tmp/elite-g2-1050-source-diagnosis/SOURCE-DIAGNOSIS.json. See [motivation](ISSUE-freight-native-hold-precondition.md).

## Focused freight qualification1055

Matching1054warm build passed45.45native /47.499outer seconds. The single1055freight method/case passed11.996native /16.438inner /18.758outer seconds, with zero issues or unknown outcomes. All1,967 guarded artifacts, tracked source and primary preferences remained exact;61 build and10 runtime actual starts independently closed, without timeout/cleanup. Lease1055 is released. Runtime qualificationSHA256 `c0dcf7f0518b96bc4347a357e75c4ead65c82c82845f4d028dc5589f836078a1`; closureSHA256 `0093ffb908ef525a464f7ebb5c0e4d5dfe8520b535ce7595df18ccfaf7200684`.

The exact reviewed test source f3bc60ca9ad8d9b3c787fa3adad9566c04c7adf9 is integrated. Independent causal reviewSHA256 `5e305bccbf6e28e10c0bc350840cbb82c259304971494bfa4fdccc7a2172df2c` is clean. Real paid hold filling, insufficient space, stale-quote refusal, complete Commander/file rollback and empty instances all pass; no capacity, starting cash or source catalogue value is changed. Prior six methods/eight cases and G08 aggregate33/53 are retained without replay. Full1050 remains FAILED, and the station method/two cases are still held; no full eight-method/eleven-case pass is claimed.
