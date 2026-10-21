# Contract completion buffers overlap actual event processing

The exact thread-sanitized binary stopped on a guard-page access during pledge receipt joins reached from the real contract-quote dry run. The observed path includes actual acceptance, event draining, pledge completion and receipt validation. The binary audit found two Game-sized reservations in performContractAcceptance before draining: its required atomic candidate and a later read-receiver buffer used by post-drain completion checks.

Keep the real dry run, required candidate and actor rollback snapshot. Move only post-drain validation storage into a later phase while retaining suspension, admission cleanup, completion, Commander validity and publication order. See [implementation](PR-contract-validation-lifetimes.md).
