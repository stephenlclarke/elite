# Compile the original combat regressions without mutating a macro receiver

The first focused M03 build at cb058b37 exited 1 before any test method began. Swift Testing expands two required mutating calls through an immutable receiver named $0: ElectricalReserve.drain and Game.fireMissile in OriginalCombatCostsUnitTests. The compiler correctly rejects those generated closures. The surrounding SwiftCompile batch messages are cascading build failures, not separate gameplay assertions or a resource failure.

Retain the actual compiler log and zero-method failed receipt. Evaluate each operation once immediately before its required Boolean assertion. Preserve state, parameters, ordering, all numeric values and every later assertion. No production or resource-policy change is required.
