# Exercise native view and work guidance through painted input

## Change

Native frame and MacBook control tests now use the existing actual-view draw helper before protected key input and verify the emitted packet's decoded presentation and key. The Blackjack contact test similarly verifies the real page-click packet, painted presentation and converted pointer coordinates. Raw unprotected keys and all existing control/held-key assertions remain intact. The standalone MacBook input fixture uses a bounded 512-by-518 viewport so its actual paint has a valid bitmap size.

The work fixture paints before protected Tab/R input and verifies the actual packet before its unchanged key release and ordered delegate consumer. All work-scene setup, native actor selection, motion, mining/salvage resources, custody and test bodies remain unchanged. Existing capture parity, timing and evidence names are untouched; preparatory drawing creates no additional evidence files.

## Validation and limits

Strict Swift formatting, whitespace and Markdown checks passed. Source comparison confirms that all work-guidance test bodies and its named capture/timing path are unchanged. No production input, fabricated packet, direct selection change or adversarial no-paint helper was introduced. Compilation and native test execution remain pending central validation.

See [the issue](ISSUE-native-view-painted-input.md).
