# Two collision fixtures need explicit measurement scope and retained contact facts

## Actual failures

Hosted39943 recorded one component-geometry miss assertion and one station pressure first-contact assertion. The component query atx50 missed the mission hull but returned an unrelated actual rescue station because the helper queried the entire populated scene. The station pressure ray returned body13 instead of the player, without printing its selected hull, position or hit point. Neither failure establishes a production collision bug or attributes the later SIGBUS.

## Source evidence and authorized scope

measuredNPCContact has exactly five call sites, all inside the selected component geometry method's verification helper. The fixture already clears celestials and explicitly measures a target at2000 with a turret, bounding-sphere miss and original hull-distance checks. Its measurement query must restrict bodies to that actual target. Actual native impact application, ally laser proof, target destruction and no-player-bounty flow remain independent and unchanged; this is a target geometry unit boundary, not proof that a shot passes through a full populated scene.

The station case must retain all actual traffic. Existing stationAutoRequireNativePressureLane performs the identical1500 zero-radius mounted forward query, excludes only the shooter, requires actual player first contact and records existing bounded failure facts. Reuse it only in this selected case instead of duplicating the query without facts. Do not move a mount or attacker, ignore body13, remove traffic, change physics or claim the station setup fixed before actual results.

## Ownership and next step

Root approved G2 only ScriptNPCTests.swift, the selected StationAutoDefence method and paired notes. One coherent independent complete-method/helper bugs/performance/style review precedes G1's matching build and only two existing methods/cases, optionally composed with another ready selection without delay. Station may still fail truthfully; actual diagnostic facts inform Root's next bounded decision. No author execution/probe or new diagnostic helper/flags. Prior batches, production/defaults, other helper consumers and G3 G08/G1 crash work remain untouched. See [handoff](PR-hosted399-collision-boundaries.md).
