# test: scope component geometry queries and retain station lane failure facts

## Change

measuredNPCContact now requires the actual targetID and excludes other body IDs only from that helper's target-geometry measurement query. All five existing calls pass the originally established target ID. No bodies are removed or moved by this delta. Turret identity, energy and destruction, exact1991/1940 measured distances, bounding-sphere miss, native contact/origin application, ally actual laser proof and no-player-bounty assertions remain unchanged. The helper is used only by componentRayHitsUseMeasuredGeometryAndCannotBecomeHullDeathOrPlayerBounty through its existing verification helper.

stationAutoUncoveredNativeBeamCannotHandOverToStationaryAlignment replaces only its local ray/contact prerequisite with existing stationAutoRequireNativePressureLane. It retains the identical body-mounted forward direction,1500 range, zero radius, shooter-only exclusion and strict actual first contact with the player. Existing on-failure facts print target, hit point, selected hull and position. No shared diagnostic or pressure helper is modified. All later real beam/shield, actor origin, laser/mount, unlawful incident, native guidance, acceleration, destination and movement checks remain intact. All traffic and poses stay unchanged; this is diagnostic observation, not an asserted station fix.

## Selection and validation

M01-hosted399-collision-boundaries: G2 author, Root coordinator, G1 executor/integrator. Exactly two tests paths plus paired notes on39943f45. Selection is componentRayHitsUseMeasuredGeometryAndCannotBecomeHullDeathOrPlayerBounty and stationAutoUncoveredNativeBeamCannotHandOverToStationaryAlignment: two methods/two cases, two recorded issues. No other shared measurement consumers exist; existing station helper consumers are unchanged and not repeated.

Scoped strict Swift format, Markdown lint, whitespace, original-assertion and source conservation checks precede freeze. One coherent independent review and exact frozen hashes are recorded in the packet. G1 performs the matching warm build and selected existing cases after its lease, with a possible strict station failure retained as useful facts. No author build/compiler/test/probe/native runtime, row/seed search, physics/production edit or passing-cohort replay. Earlier first/second frozen packets remain untouched. Runtime qualification, global review/quality gates and release are pending; no full CI or crash-cause claim. See [motivation](ISSUE-hosted399-collision-boundaries.md).
