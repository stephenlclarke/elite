# Issue42: stale deferred-stage expectations

Original rescue receiving delivered the stage9 source transition and changed the truthful deferred-stage notice to stages10–14. The maintained VaultKey assertion at line80 and Continuation assertion at line208 still expected9–14. Collector-enabled39711047075 reported both actual failures. Preserve surrounding custody/progress/reward assertions and update only these two expected boundary strings.
