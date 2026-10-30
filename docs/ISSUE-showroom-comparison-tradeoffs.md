# M02.P04 / F06: keep showroom tradeoff hints consistent with SAME

Native comparison rows round to tenths and rate equal displayed values SAME. The separate tradeoff hints compare the raw numbers. SH062 Imperial Clipper has native speed 34.286; SH025 Peregrine Mk V has 34.3. Both display 34.3 speed and SAME, but selecting SH025 against SH062 says Higher maximum speed. Reversing them says Lower maximum speed. These hints contradict the visible capability comparison.

Both models already render in compact detail and wide views with the same pitch, roll and yaw. Projected carried-fit values already reuse the real equipment-transfer rules. Credit those implementations and preserve them. Fix only the native tradeoff projection, retaining visible differences, explicit source-profile units and all transaction authority. [Implementation](PR-showroom-comparison-tradeoffs.md).
