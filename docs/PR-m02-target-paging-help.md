# fix(help): hide unavailable target-detail paging hints

The flight reference now omits its target-detail paging row when the current panel cannot page. A pure targetDetailsWindow projection extracts the existing input guards and layout unchanged, so paging and help use the same target, identification tier, expansion and viewport. All other help rows and the generated six-action footer remain intact.

One new ContextControlHintUnitTests method exercises absent and selected targets, three targeting tiers, explicit and width-dependent expansion, compact and tall viewports, direct help and its overlay. It compares the hint with the actual paging keys and checks weapon/target selection, world bodies and time remain unchanged. The original inventory and system help tests are retained. The existing selector needs only the new targetPagingHelpFollowsActualIdentificationExpansionAndViewportWithoutChangingSelection method; this packet does not edit CI or the shared ledger.

Strict Swift formatting, scoped Markdown and whitespace checks are the local validation boundary. No Swift build, test execution, native app, GUI or process probe runs while G1 owns the M01 pipeline. The new method remains UNRUN; independent source review and actual focused qualification remain pending. This source fix does not establish all M02 completion or a usable release.
