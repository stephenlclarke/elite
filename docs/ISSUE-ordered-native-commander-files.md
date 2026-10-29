# Preserve the order of native Save, Load and Open commands

CR-01 is a P1 data-loss bug. Save queues a path in the native view, while Load and Open start independent tasks. Opening Commander B before the queued Save drains can therefore write B into Commander A's file and change the active path back to A.

All four file actions must share the existing ordered native input stream. Plain Save and Reload resolve the active path at their position in that stream; Save As and Open retain the explicitly selected URL. Update active paths and preferences only after the corresponding actor operation succeeds. Preserve earlier queued refits, failed-operation rollback, session epochs and selected-file bytes. See the [repair handoff](PR-ordered-native-commander-files.md).
