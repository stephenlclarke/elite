# Unlimited retaliation fixture disagrees with owned ammunition

Full run 222 reports missing launch announcements in `unlimitedRetaliationAndNewAttacksRespectAmmoAndManualDisarm`. The fixture sets the missile count to zero after launch has prepared an inventory containing three fitted rounds. Equipment validation requires the count to match fitted ammunition, and missile launch validates equipment before quoting unlimited consumption.

This is a source-backed crosswalk diagnosis; the exact caught runtime error was not observed. Establish zero fitted ammunition through normal storage transactions, preserving validation and the original retaliation checks. See [the correction](PR-retaliation-owned-ammo-fixture.md).
