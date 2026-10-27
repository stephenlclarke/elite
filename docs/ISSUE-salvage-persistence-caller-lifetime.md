# Salvage persistence ancestor of EMP archive capture

The unchanged EMP smoke in run 478 still crashed in archive capture on compiled source `67cdb1be7e9a97b9fe3cbe5680eb5a320c142951`. The retained 477 object observations show `persistSalvagePosesInPlace` as an active ancestor of EMP persistence/archive/record capture, with 24 probe GOT relocations and five Game copy witnesses. These counts are not aggregate stack bytes or measured removable peak usage.

The caller starts by persisting EMP state, but its complete subsequent salvage ledger, body observation and ordered flush logic resides in the same function. Those dormant value temporaries belong after the EMP call has returned. The caller boundary must become an enforced thin EMP guard followed by a non-inlined post-EMP helper, preserving every original failure/no-op, identity/motion observation and flush sequence. The outer cold Commander/work/wreck/lot rollback must remain verbatim.
