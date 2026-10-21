# Image parity does not measure native frame pacing

Focused GPU 288 proved five image/cache/fallback/production-renderer methods with the experiment enabled, including seventy-two affected and thirty-two new night comparisons. It did not measure the normal application frame loop in compact or actual fullscreen windows. The night cache key follows the actual moving sun, so unchanged image parity is insufficient evidence of presentation pacing.

Add an opt-in diagnostic observing the existing GameRuntime-to-view path, frame deadline and AppKit draw callbacks, with actual viewport/backend/control/state evidence and renderer captures. Keep commander files and preferences isolated. See [implementation](PR-native-planet-frame-profile.md).

Independent review of the first source draft found that repeated AppKit redraws could overwrite distinct-frame intervals and that four seconds of view rotation did not prove a close flyby. The revised observer keeps first draws and raw redraw/coalescing evidence separately, with phase-bound interval history. Separate fresh compact/fullscreen cases now drive the actual original forward launch corridor with normal throttle and require measured planet/star close-pass, safety and front-to-rear predicates. At that source-review stage, native execution remained pending.

The revised source review also found that disabling startup restore did not isolate legacy TOML mission loading. Profiling now supplies its own absent pack directory, retaining bundled missions while normal launches keep the original default loader call. No installed mission pack or user preference participates in the controlled scenario.

## Verified development comparison

The maintained diagnostic subsequently produced matched baseline 497/498 and after 504/505 flybys. Development source `a71af8c7` reduced compact/fullscreen median draw intervals from about 17.7 ms to 16.66 ms with lower p95 intervals. The [durable report](NATIVE-FRAME-PACING.md) records protocol, source/executable and evidence fingerprints, warming/trajectory qualifications and the retained compact baseline wrapper issue. The coherent batch includes cadence, geometry and save changes; full gameplay, CI and release acceptance remain separate.
