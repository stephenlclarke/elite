# Observe committed hull and fitting changes

The native ship comparison omits fitted missile and laser counts even though its carried-fit contract distinguishes installed weapons from empty mount capacity and stored property. Successful hull exchanges also never produce the already-declared `ship.changed` event. Native store/refit actions similarly omit `equipment.changed`, leaving mission observers unaware of actual custody changes.

Publish those observations exactly once after the corresponding successful native change. Preview, Back, paused or incompatible actions and failed actor writes must leave physical ownership and mission progress intact. Event-capacity exhaustion must refuse the physical change rather than lose its observation. Preserve the original observer and pure-preview regressions. The occupied-cabin regression must use a current zero-hold compatible hull; SH128 is now the 12t Transporter.

See [implementation and validation](PR-committed-ship-profile-events.md).
