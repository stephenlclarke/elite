# Clinic acceptance fixtures contradict actual fitting and visit guards

Existing hosted231-method run39731389269 at1523b3ee reports three failures from two fixture roots. The accepted booking declares inventory revision1 while its constructed commander retains revision0. Two positive owning-save assertions therefore correctly refuse that commander. The later workshop-consent fixture also omits its actual registered Enmadan station and newer visit, so the positive historical-contact assertion correctly refuses it.

Correct the fixture inputs to match the declared typed receipts. Keep production fitting revision, owner, clock, acknowledgement and actual station-history guards unchanged. Reuse the existing affected methods and hosted execution; no native journey or new diagnostic job is needed. Refs #49, #50 and PR25 and C08.P06.B.clinic.acceptance.
