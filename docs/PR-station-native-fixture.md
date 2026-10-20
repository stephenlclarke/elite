# Prove narrow attained docking steps without weakening collision checks

Use actual convex-port clearance over the real player vertices to choose a bounded finer sweep when the coarse whole-hull proof refuses a nominal fit. Every interval retains the original conservative margin and complete aperture/triangle checks; counts above64 refuse the step. The original fast path and attained-source/native-motion guards stay intact.

Station fixtures initialize fuel for the selected hull, retain native anchor/body identity, reframe consistently, and cycle the actual target-selection action until the main anchor is selected, allowing at most two body-count cycles to finish retained partial history and begin a fresh bounded cycle. All six starts and existing safety, docking and timing assertions remain.

Seven methods passed in942; only the failed manual-takeover method is retried after the bounded cycle correction. The full eight-method owner selection covers four approach cases, narrow SH171 acceptance/refusal and two existing SH025 geometry/refusal checks. No rendering, geometry scaling, safety waiver or production mesh-lookup change is included. Owner unit PASS and independent coherent review precede canonical acceptance. See the [issue](ISSUE-station-native-fixture.md).
