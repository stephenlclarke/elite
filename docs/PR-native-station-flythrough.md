# Render complete station surfaces and resolve structural contact

## Problem and resulting behavior

The native flyby displayed large, apparently incomplete blue panels. Actual diagnostic capture 310 identifies the object as the RRS waystation and confirms that this particular flight passed clear of its solid structure: 1423 consistent station observations, no blocked resolved sweep, and full player shields and energy. Independent source witnesses identify inverted face conventions in the closed exterior components and open receiving interiors. Separately, the collision handler applied damage while retaining the attempted player pose, allowing travel after a genuine structural contact.

Each audited component now explicitly converts its face order during assembly. Closed waystation and HQ rock surfaces face outward; open construction and receiving interiors follow their independent exterior/bore witnesses. All original vertices, embedded source faces, topology, openings, source roles and station identities remain retained. Waystation docking and launch fit use the smaller main bore (106.72374/44.20642), while the wider original liner geometry stays visible.

Structural impact now stops player cruise, residual/work momentum, spin and automatic guidance. The response reprojects current actor and celestial poses into the retained player frame rather than restoring old body snapshots, preserving earlier NPC movement, projectiles, station spin, physical time and impact damage. Original main-station wrong-side contacts use the same stop with their existing contact and doorway predicates. Motion observers receive the retained endpoint; valid RRS entry keeps its separately swept endpoint and existing atomic publisher.

## Rotating contact and uncertainty

A rotating arm can reach a stationary ship's previous pose. When needed, the response carries that pose by the station's actual rigid rotation, bounds displacement by real surface movement and checks the full effective hull at the final station orientation and the current neighboring scene. It uses no arbitrary outward relocation or station/time rewind. Unresolved conservative contact stops and pauses flight with the existing time-scaled impact damage; it does not imply instant destruction or a proven safe endpoint. Invalid initial overlap remains unsupported.

`stationImpactRevision` records the actual contact frame. G1 must join it at the future actual post-motion provider caller so contact transport cannot earn escort calibration credit. This change does not advertise or activate that incomplete provider capability.

## Validation

Source parsing, strict formatting, scoped Markdown lint and whitespace checks passed before the source was frozen. Validation 310 passed two TSan observation tests and completed the actual compact diagnostic on the preceding diagnostic source; it is before-fix evidence, not acceptance of this repair. Fullscreen 309 stopped under the earlier ambiguous active-flight guard and remains incomplete.

The reviewed focused selection has 27 unique methods and 39 expanded cases: component exterior/interior visibility, retained closed topology, bore fit, near-plane panels, actual manual/residual/work impacts, stationary rotating contact, independently moving NPC conservation, unresolved-contact refusal of instant death, genuine RRS/main doorway entry, automatic docking, native save/reload and entry-writer rollback. Original iterations, time steps and concurrency remain unchanged. Validation 311 compiled the repair and completed 23 methods, including all new surface and impact regressions, before the unchanged 600-second limit. Four longer physical methods remain unfinished. The exact failed-run artifacts are preserved. The follow-up [station validation change](PR-native-station-validation.md) must retain those original methods and limits. One comparable corrected compact/fullscreen native capture remains required after focused completion.

## Compatibility and remaining acceptance

The geometry correction retains adapter identity `rrs-native-geometry-v1`, source coordinates, saved poses and receipt formats. Historical native entry already required a whole-hull structural sweep; the corrected fit envelope does not replace that proof. The read-only opt-in diagnostic projection and bounded AppKit captures confer no gameplay or docking authority. Their extra observation work requires identical instrumentation for any performance comparison.

Full CI, coverage, sanitizer/leak gates, renderer-generated media, a completed clean GitHub review, protected merge, main-branch SonarQube and distribution validation remain outstanding for the coherent release. No native visual correctness, full-screen smoothness or before/after performance improvement is claimed by this source handoff.

## Link

[ISSUE-native-station-flythrough.md](ISSUE-native-station-flythrough.md).
