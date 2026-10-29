# Utility held-fire safety must compare actual starting resources

Refs [issue47](https://github.com/stephenlclarke/elite/issues/47), PR25 and C08.P05.B.work. Game initializes energy from the commander's actual performance. The hosted safety method incorrectly assumes the property's old256 declaration default, so its no-weapon-effect assertion fails despite unchanged latch-only resources. Preserve the safety invariant against actual pre-action values; do not alter production hull stats.
