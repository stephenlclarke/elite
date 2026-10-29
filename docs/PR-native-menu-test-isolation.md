# fix(tests): serialize the native Wanted Board menu fixture

The native Wanted Board method now extends the existing serialized `NativeViewTests` suite. Its setup, helper access, menu restoration, real input/rendering assertions and two viewport sizes are unchanged. The same-file top-level helper remains accessible. This prevents that method from restoring the process-wide menu while another native suite member is suspended.

The maintained `appkit-shared-process` group replaces the method's `WantedBoardTests` ID with its `NativeViewTests` ID, restores sorted membership and updates only the Wanted Board source SHA256. It retains all 170 AppKit members and the same participant files. This keeps the existing manual grouping metadata valid; sanitizer commands remain optional and default-off.

Focused offline validation passes the existing Python grouping regression, including its member, participant and source-drift refusals. The maintained inventory, grouping and partition functions also accept the prior actual 3,403-method discovery after mapping this one ID to its new suite. Static comparison confirms the Swift delta changes only the extension owner, and the manifest delta changes only that member and its source hash. Markdown lint and whitespace checks pass. No new test or framework is added; the existing native Wanted Board and gallery behavior assertions remain the regression coverage.

The mapped inventory is static evidence, not fresh Swift discovery or native execution. No Swift/compiler/native test, sanitizer, process probe or live-checkout modification is performed. The packet remains in validation pending: G1 integrates after the live phase reaches its terminal result, Root arranges one combined independent review, and G1 supplies the relevant exact-head native validation and required final checks. The cleanup correction from parent `2674bfa6` is retained, and no production menu, guard, test scope or branch protection changes.

Related issue: [native menu fixture interference](ISSUE-native-menu-test-isolation.md). Existing project PR: [277](https://github.com/stephenlclarke/elite/pull/277).
