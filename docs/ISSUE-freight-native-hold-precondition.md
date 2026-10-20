# Incorrect fixed cargo capacity blocks the freight stale-quote fixture

Actual1050 fails freightNativeConfirmationRefusesHoldFilledAfterReview at its newly added prerequisite: the stock SH023 fixture has native cargo capacity30, while the assertion requires20. Its original100000-unit budget passes. The test therefore stops before exercising real paid hold filling and stale confirmation refusal.

Remove only the unsupported capacity conjunction from the reviewed fixture source. Preserve the stock Cobra setup, actual paid G03 preparation, generated freight quote, market purchases, insufficient remaining hold, refusal, full Commander and file rollback, and empty script instances. No production or shared helper change is required. See [implementation](PR-freight-native-hold-precondition.md).
