# Issue 34: target failure blocks later carried-material loss

A W04 target-destruction failure retains its original held batch. A later actual escape or ship destruction changes the native consignment to lost, but the terminal command and save joins accepted only an unpaid return. Native publication then rolls back and can abort the escape.

The fix must retain the original failure receipt, zero settlement, clue history and exact material/source/hull/route/reach/reward evidence. It must accept only the later native loss or unpaid source return, with valid cause, energy and native visit/time bounds. See [issue 34](https://github.com/stephenlclarke/elite/issues/34) and [correction details](PR-field-relief-later-loss.md).
