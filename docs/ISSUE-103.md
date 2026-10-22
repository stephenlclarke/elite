# Issue #103: compile the borrowed retained fit lookup

## Problem

Automatic run `39785814462` at head `c8728210` failed production compilation in `ScriptNativeBridge.swift`. The compiler reports that borrowed `body` and `retained` are consumed by the non-NPC `&&` autoclosures at line 87, and that borrowed `retained` is captured by the component `allSatisfy` closure at line 91. No runtime method executed. This compile criterion is separate from runtime issue #98.

## Correction and acceptance

Keep the same ordered non-NPC predicates using direct hull and optional `.none` guards. Replace the component closure at the same guard position with a non-inline borrowed helper. It copies only the COW component dictionary for iteration and keeps the full retained actor borrowed. Iterate in the same dictionary order, compare the same optional component UUID, stop at the first false result and return true for an empty dictionary. Preserve every other profile/model/identity/authority check and all 362 selected methods.

Run the single explicitly leased Core compiler preflight before push. Keep local unit/native/probe execution prohibited. Record its actual result and release the lease. Actual corrected compilation is required to close #103; the native runtime acceptance criteria #85/#96/#97/#98 remain separate and pending.

The single leased production Core preflight passed in 59.04 seconds with exit 0, and its CPU lease was released. It does not compile the test target or prove runtime acceptance. Corrected exact-head hosted compilation and independent review remain pending before closure.

Actual hosted run `39787112105` at `63ded61c` completed production/test-target compilation in 917.40 seconds. #103 closed on that evidence. Its later runtime stack failure remains tracked by #98; no runtime criterion is inferred from this compile-only closure.
