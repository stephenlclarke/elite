# The mission fault recovery sale assertion uses the buy price

Actual667 reports a failure at ScriptGalleryTrialTests331 after a genuine native market sale. Original-world markets now have separate ask and bid quotes. The test correctly sells one tonne and checks cargo, market stock, retained mission state and free capacity, but expects the credits for a sale to increase by the ask quote.

The sale expectation must use the actual market bid. Production pricing and the native market input path remain unchanged. See [the correction](PR-gallery-market-sell-bid.md).
