<!-- markdownlint-disable MD013 -->
# Actor snapshot test retains the retired commander name

[Issue #114](https://github.com/stephenlclarke/elite/issues/114) tracks the single obsolete name assertion exposed when the existing actor snapshot test joined the maintained isolated selection for [PR #107](https://github.com/stephenlclarke/elite/pull/107). Independent comparison confirms both the test and NewCommanderDefaults are byte-identical to the pre-repair 7d67 baseline. Historical change86cca and the approved F01 specification replaced JAMESON with the original-world default Rowan Calder; production setup uses NewCommanderDefaults and changes to CLARKE only when XYZZY is actually enabled.

Correct only the expected normal commander name to NewCommanderDefaults.name. Preserve the negative XYZZY check, full Commander equality, retained caller snapshots, actual CLARKE grant, equipment and authority checks. No production name, identity, mode, actor or ownership behavior changes are needed. See [the repair note](PR-actor-snapshot-name.md). The original failing assertion remains retained with its actual binary and output.
