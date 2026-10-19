# fix(missions): read arrival fuel before updating wormhole receipts

Game.performNativeArrival reads its actual current fuel into a local integer immediately before assigning the same native passage receipt. No intervening mutation, copied Game, invented fuel, changed receipt field or changed optional write is introduced. This avoids Swift 6 overlapping access to Commander while preserving the sealed arrival's once-only fuel/calendar evidence.

Actual failed compiler evidence is retained under /tmp/elite-launch-compile-650; no tests ran, and mixed artifacts cannot certify current runtime behavior. Scoped Swift formatting, Markdown and whitespace checks validate the source; the corrected coherent build and authored native passage/cohort tests remain pending. No full CI, coverage percentage, sanitizer, leak or release acceptance is claimed. No GitHub issue or PR exists for this leaf. See the [issue](ISSUE-native-wormhole-receipt-exclusivity.md).
