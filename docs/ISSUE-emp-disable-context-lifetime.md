# Physical context construction overlaps the EMP disable frame

Exact-binary diagnostic 283 stopped in `gameplayContext` during the unchanged full-actor-capacity EMP regression. The physical context frame occupied 49,136 bytes beneath the 188,048-byte disable helper; the stack pointer was in a mapped guard page. The original seventy-method run had exited with signal 4 and no completed summary. These observations establish the diagnostic's actual path, without proving causal equivalence to the original signal or passing any gate. The exact binary is `e4928c96f9a60acd765594c1b3c4bba5e417198be13bab160aedc005c6d44355`.

The context is a read-only snapshot of the already recorded electrical hit. Construct it in the same real-zero branch before entering the large disable helper, then pass that exact value through the existing protection and source-custody checks. See [the repair](PR-emp-disable-context-lifetime.md).
