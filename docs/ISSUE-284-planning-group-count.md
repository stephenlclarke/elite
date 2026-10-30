# Update the planning fixture for the two reviewed namespace tests

PR283 initial CI run41022444335 failed the real hosted PlanningTests case: expected group inventories173/33 and13/2, actual175/33 and13/2. Its separate event-authorization refusal used the previous main policy and did not cause this fixture failure. No native checks started.

The authenticated e691-to-d651 manifest comparison normalizes only the module namespace. It proves the original173 AppKit members keep their exact order, the33 source paths remain, and only the two reviewed NativeView namespace/preference methods are appended. The second13/2 group remains exact. Both new methods already passed in the actual40-method qualification. The maintained group count expectation must reflect this intentional inventory; do not alter the manifest, remove tests, skip grouping or weaken whole-group assertions.

Linked issue: [284](https://github.com/stephenlclarke/l337/issues/284). Parent pull request: [283](https://github.com/stephenlclarke/l337/pull/283).

The affected PlanningTests suite now passes all eight methods locally. The raw log is retained as `/tmp/l337-m03-planning-correction-tests.log`. This changes one expectation only; no Swift run is repeated. Independent changed-source/result review and fresh final-head hosted checks remain pending.
