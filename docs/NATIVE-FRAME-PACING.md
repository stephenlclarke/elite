# Native frame pacing: measured development comparison

Recorded 19 October 2026. Matched compact and fullscreen flybys show improved draw-interval pacing in development source `a71af8c70281a0909958c05355f147d7945a18f0` against `b0e4108991293e6a04a85f8640a913563e2e6b4f`. This is a controlled application measurement, not a published release, physical scanout/input-latency result or guarantee of 60 FPS in every gameplay situation.

## Results

Intervals measure the first AppKit draw of each distinct submitted frame. Reciprocal median FPS is `1000 / median interval in ms`, not a separate physical refresh measurement.

| Window and viewport pixels | Median interval before / after (ms) | p95 interval before / after (ms) | Reciprocal median before / after (FPS) | Distinct draws before / after |
| --- | --- | --- | --- | --- |
| Compact, 1024x1080 | 17.721416 / 16.655625 | 18.283458 / 17.643666 | 56.43 / 60.04 | 1421 / 1509 |
| Fullscreen, 3600x2260 | 17.705959 / 16.658250 | 18.311625 / 17.503250 | 56.48 / 60.03 | 1423 / 1509 |

Both after runs recorded zero repeated draws and zero coalesced/undrawn submissions. Their p95 intervals remain above a 16.67 ms frame interval; the near-60 reciprocal medians do not mean every interval met that deadline.

The cadence change preserves a deadline phase across late wakes, uses an explicit 100-microsecond sleep tolerance and skips overdue slots instead of immediately catching up. Actual elapsed simulation delta is unchanged. The measured after source also contains separately reviewed geometry/save changes, so this comparison supports improvement in the coherent development batch, not unique causal attribution to the cadence change. See [the cadence implementation](PR-phase-anchored-frame-cadence.md).

## Matched protocol

Each window mode used an independent launch of the ordinary AppKit/GameRuntime/renderer path with a fresh normal Commander Jameson. Initial ship, resources, world, hardware/backend, controls and physical-origin/world-plane checks matched within each before/after pair. The retained profiles identify the Apple M5 Pro backend. No XYZZY hardware, invulnerability, teleported pose or replacement draw loop supplied the result.

The maintained diagnostic warms the ordinary window/renderer, launches through key 0, coasts for one physical second, then holds three-finger acceleration on the original forward heading. Camera keys keep the approaching and receding bodies visible. Completion requires actual safe planet/sun close passes, both front-to-rear crossings and travel beyond the sun's far plane. Fullscreen waits for actual AppKit acknowledgement before launch. The [diagnostic protocol](PR-native-planet-frame-profile.md) describes the observer and isolation boundaries.

Wall-clock warming and elapsed-delta timing naturally differed. The matched comparison verified physical origins and world planes, with closest-range differences below 0.01 native unit: compact planet -0.002362 and sun +0.000873; fullscreen planet +0.002085 and sun +0.000323. These are matched trajectories, not identical wall-clock samples.

To reproduce, use the exact already-built executable corresponding to the source and executable hash below, with a fresh output directory for each independent launch. Checking out a source revision alone does not identify its executable. These commands describe the maintained protocol; they were not re-executed for this documentation closeout.

```sh
verified_app="/absolute/path/to/verified/Elite"
verified_source="a71af8c70281a0909958c05355f147d7945a18f0"
shasum -a 256 "$verified_app"
"$verified_app" --profile-planet-frames \
  /absolute/path/to/new-compact-evidence "$verified_source" compact
"$verified_app" --profile-planet-frames \
  /absolute/path/to/new-fullscreen-evidence "$verified_source" fullscreen
```

A baseline comparison uses the baseline executable/source pair through the same commands and protocol. The diagnostic isolates commander output and preferences, disables startup restoration/default external Lua loading and directs legacy TOML loading to a fresh absent directory while retaining bundled missions. Raw intervals include queue/GPU waits and are not CPU-only timing.

## Source and retained evidence

| Identity | SHA / SHA-256 |
| --- | --- |
| Baseline source | `b0e4108991293e6a04a85f8640a913563e2e6b4f` |
| After source | `a71af8c70281a0909958c05355f147d7945a18f0` |
| Baseline executable | `2caef05f313167e7cda9fd043c57d0c4f23072a0d47a808e29305d892ab2df57` |
| After executable | `cc4a505024290a3dfa5572a3de9bf79251b7cffb7053dd41e1405dba8a5ef23d` |

The validation archive retains the following original artifacts. Names and fingerprints identify the evidence without committing host-private audit files or copying their screenshots into the repository.

| Artifact | SHA-256 |
| --- | --- |
| `elite-native-frame-before-after-500.json` | `ddaca7fae1347cb5bc902e1d45bba847ad03f2ff8498ed4064125b1222c5847a` |
| Baseline compact `agent-game-frame-verification-497.json` | `a4bb321bb005dbd5f273c7d280936a1248c6844f6fa409260773bf4a663a8f0f` |
| Baseline fullscreen `agent-game-frame-verification-498.json` | `7559ea69d0a23a62fda0942a1f97b9903bf57226851b4a1162c57139aadfa4dc` |
| After compact `agent-game-frame-verification-504.json` | `c5515ff2417b273a74246f7cc91c6eb0b6b76156b450f455bc5397fb9b1ee8ee` |
| After fullscreen `agent-game-frame-verification-505.json` | `a1265f81b5c696dc3d672e5cf5841d3cb9b7d5ca17f895f185bd4fffb5eb7417` |

Baseline compact run 497's application exited 0 and completed its profile, but an inherited post-run SwiftTesting-summary assertion made its wrapper exit 1. The original result and qualification were retained; there was no compact retry. Baseline fullscreen 498 succeeded. After runs 504 and 505 both exited 0 at the application and wrapper levels. Protected inputs remained unchanged and owned processes were gone after both after runs.

## Acceptance boundary

Focused run 501 passed 19 methods/20 cases: three cadence arithmetic methods and sixteen geometry methods. The unchanged original EMP smoke in run 502 passed one method with two cases. Mission run 503 still encountered a stack crash. Full `make ci`, signing, main-branch publication and release acceptance remain outstanding; the performance result does not clear those gates or qualify all gameplay. No additional build, native test, profile or renderer execution was performed for this documentation change.
