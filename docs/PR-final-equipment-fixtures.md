# Use owned pylons and migrate the original laser mounts before launch

## Implementation

The missile icon test starts with zero canonical rounds and grants one owned standard round into each pylon while retaining counts zero through four. It stores each actual round at the current inventory revision before unlimited mode. The final native launch uses an actual physical Cobra outside the station, matching the existing native ammunition fixture arrangement; new assertions verify successful launch, the target identity, virtual unlimited provenance and unchanged owned inventory.

The station laser test moves its original front Pulse, left Mining and right Beam mount seed before launch. New preconditions verify the actual kind and fitted slot, including the empty rear mount. All original two-tick damage, firing-rate and heat assertions remain. See [the issue](ISSUE-final-equipment-fixtures.md).

## Compatibility, validation and risk

No gameplay provider, purchase rule, authority check, original expected outcome, case selection or skip changes. A source check confirms every original expectation across all three assigned test files remains in order. Strict Swift/Markdown lint and diff checks pass. This worker has not compiled or executed the batch; focused tests and required composed `make ci` remain with the integration owner.
