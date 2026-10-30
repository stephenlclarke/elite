# Restore the positive Liberator purchase fixture precondition

The first full PR282 run on execution 338aa0cf completed 3,416 tests in 397 Swift Testing suites. One method failed with ten cascading issues: the positive Liberator purchase fixture tried to exchange into the declared XYZZY-only hull without XYZZY access. The new purchase restriction correctly refused the quote; the later transfer, flight, docking, save and material expectations then still observed the old Cobra.

Prices, equipment transfer and physical simulation did not change. The existing new policy regressions already prove ordinary denial, XYZZY admission and access revocation. The positive purchase fixture must explicitly establish access while retaining its finite cash and complete original scenario.
