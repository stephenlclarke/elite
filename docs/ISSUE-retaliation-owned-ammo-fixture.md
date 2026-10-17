# Unlimited retaliation fixture disagrees with owned ammunition

Full run 222 reports missing launch announcements in `unlimitedRetaliationAndNewAttacksRespectAmmoAndManualDisarm`. The fixture sets the missile count to zero after launch has prepared an inventory containing three fitted rounds. Equipment validation requires the count to match fitted ammunition, and missile launch validates equipment before quoting unlimited consumption.

This is a source-backed crosswalk diagnosis; the exact caught runtime error was not observed. Establish zero fitted ammunition through normal storage transactions, preserving validation and the original retaliation checks. See [the correction](PR-retaliation-owned-ammo-fixture.md).

The completed focused 226 also showed the shared helper adding ECM as an unowned raw flag after canonical inventory creation. Legitimate storage mirrors fitted equipment and removes that flag. Both actual ECM ownership and physical negative equipment-loss/empty-rack states are now required, preserving original retaliation outcomes rather than changing the ammunition kernel.
