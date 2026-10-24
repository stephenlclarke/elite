# Native-painted courier caller requires a dedicated one-hop witness

Actual group 691 passed all six runtime courier delivery cases, six deadline boundaries and prior-input refusal checks. Its native-painted caller failed the retained `physicallyDeliverCourier` precondition `terms.path.count == 2` at ScriptCourierGalleryTests.swift:319. The shared row-zero runtime witness is a valid two-hop route, G01-S004 to S084 to S241, so it does not satisfy that narrower input helper.

Preserve the qualified runtime witnesses and their multihop coverage. Add a separately named authentic one-hop row-zero witness only for the native-painted caller, retaining every original physical travel, hardware, input, custody and reward assertion. Do not weaken the helper, reroll a live board or select a quieter encounter. See [the correction](PR-painted-courier-onehop-witness.md).
