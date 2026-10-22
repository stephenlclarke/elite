# Issue67: a later clinic release needs its later actual dock

The three-operator seed fixture requests release270 after workshop/seed releases at docks105/106, but its helper reuses the clinic's old consent dock104. The unchanged finite ledger correctly refuses this backwards chronology before source-preservation assertions run.

Use a later actual clinic dock and bind that dock into the release identity with the current capacity revision/fingerprint. Keep the actual three original sources, selected owner/unit, release chronology and Avenor read-only pickup refusal. Do not weaken production checks or remove the positive assertions.

Refs [issue67](https://github.com/stephenlclarke/elite/issues/67). This is a concrete fixture input error, separate from issue60's unexplained SIGNAL4 exit.
