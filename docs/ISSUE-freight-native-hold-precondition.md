# Incorrect fixed cargo capacity blocks the freight stale-quote fixture

Actual1050 fails freightNativeConfirmationRefusesHoldFilledAfterReview at its newly added prerequisite: the stock SH023 fixture has native cargo capacity30, while the assertion requires20. Its original100000-unit budget passes. The test therefore stops before exercising real paid hold filling and stale confirmation refusal.

Remove only the unsupported capacity conjunction from the reviewed fixture source. Preserve the stock Cobra setup, actual paid G03 preparation, generated freight quote, market purchases, insufficient remaining hold, refusal, full Commander and file rollback, and empty script instances. No production or shared helper change is required. See [implementation](PR-freight-native-hold-precondition.md).

## Focused freight qualification1055

Matching1054warm build passed45.45native /47.499outer seconds. The single1055freight method/case passed11.996native /16.438inner /18.758outer seconds, with zero issues or unknown outcomes. All1,967 guarded artifacts, tracked source and primary preferences remained exact;61 build and10 runtime actual starts independently closed, without timeout/cleanup. Lease1055 is released. Runtime qualificationSHA256 `c0dcf7f0518b96bc4347a357e75c4ead65c82c82845f4d028dc5589f836078a1`; closureSHA256 `0093ffb908ef525a464f7ebb5c0e4d5dfe8520b535ce7595df18ccfaf7200684`.

The exact reviewed test source f3bc60ca9ad8d9b3c787fa3adad9566c04c7adf9 is integrated. Independent causal reviewSHA256 `5e305bccbf6e28e10c0bc350840cbb82c259304971494bfa4fdccc7a2172df2c` is clean. Real paid hold filling, insufficient space, stale-quote refusal, complete Commander/file rollback and empty instances all pass; no capacity, starting cash or source catalogue value is changed. Prior six methods/eight cases and G08 aggregate33/53 are retained without replay. Full1050 remains FAILED, and the station method/two cases are still held; no full eight-method/eleven-case pass is claimed.
