<!-- markdownlint-disable MD013 -->
# test(commander): use the approved default in the retained actor snapshot check

The existing actor snapshot test expected the retired JAMESON name after normal setup. It now compares against NewCommanderDefaults.name, the approved Rowan Calder default. The same expression still requires XYZZY to remain disabled in the retained snapshot. Every full Commander, caller copy, actual CLARKE grant, equipment and authority assertion remains unchanged.

Independent baseline/history/specification comparison established the stale expectation before this one-token oracle correction. Production defaults and runtime behavior are unchanged. The method remains in the maintained isolated selection. Its affected runtime result is recorded in the related [rescue/custody repair note](PR-rescue-acceptance-frames.md); source review does not imply a passing run. This addresses [issue #114](https://github.com/stephenlclarke/elite/issues/114) in [PR #107](https://github.com/stephenlclarke/elite/pull/107).
