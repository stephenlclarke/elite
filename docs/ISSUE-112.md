<!-- markdownlint-disable MD013 -->
# Native rescue acceptance frame during genuine mission preparation

[Issue #112](https://github.com/stephenlclarke/elite/issues/112) tracks this distinct release blocker, found while validating the original-rescue body preflight on [PR #107](https://github.com/stephenlclarke/elite/pull/107). It is separate from the recoverable-dispatch refusal in [#108](https://github.com/stephenlclarke/elite/issues/108).

The local focused build passed in59.23seconds. Ordinary native ship selection passed in8.567seconds, then SIGBUS10 stopped the other methods. Normal macOS report swiftpm-testing-helper-2026-10-23-001056.ips matches PID21319, launch00:10:40.2550+0100 and image UUID74903D28-8D75-37ED-AD97-23DB197DB8A4, independently checked against the retained test binary. Fault0x16f4a3dd0 is inside stack guard0x16f4a0000–0x16f4a4000.

The actual stack is Game.commander.read, acceptOriginalRescue at its first slot-policy read, mutate/publish rescue action, native people/contract board input, GameRuntime and the genuine rescue classifier fixture accepting its original mission. The changed rescue facts provider is absent from that faulting stack. No fixture or baseline oracle was weakened to bypass the real acceptance flow.

The exact local acceptance function begins at0x5d91e00. Its prologue reserves0x8e90fixed bytes plus many dynamic temporaries for later offer, custody, journey-state, mission and Commander operations before the first slot check at line290. These later values are not yet needed for that first read. Separate the synchronous acceptance phases without changing any slot/validation/error order, source identity, berth/resource allocation, mutation sequence, unpublished candidate, final validation or event drain. Commander fields and all save schemas must remain unchanged.

See [the repair note](PR-rescue-acceptance-frames.md). Earlier failed artifacts and the successful ordinary-ship case remain retained at their actual scope. No new full-suite or release qualification is inferred.
