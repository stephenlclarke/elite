# test(fixtures): preserve native prerequisites for retained oracles

## Selected setup changes

The two pledge methods keep their original SH023 and SH005 hull choices, Food counts, unlimited-legacy-cargo controls and donation/record budgets. Initial fuel, energy and front/rear shields now come from those actual chosen stock hulls before board/equipment initialization. The original 31-to-26 Food, five-tonne donation, real hold, receipt fields, once-only settlement, 220 Food and 128 retained instances/standing/receipts checks remain exact.

The matched-spin main-port method explicitly selects stock SH023 before launch, retaining radius 69, half-width 60.45841816329148, the same spin/step, necessary gate, full swept-hull clearance and no-forced-arrival assertions. The selected NPC geometry method performs the original fixture's real pack read, typed equipment initialization, mission acceptance, launch and undocked event on an explicitly initialized SH023. Its NPC vertex scaling, source profiles, full unchanged-player mesh/commander and validity assertions remain intact. The generic NPCFixture.game helper and every other caller are unchanged.

The expired-courier method uses existing CourierNativeFixture row 1, stock SH023 at origin 0. Actual native generation and pinned verification retain seed, draws, path, offer UUID and independent lower bound 35798.30051999994 seconds. The real package quote must have headroom under its unchanged 172800-second deadline before confirmation. The original three ordinary Food tonnes, deadline-plus-0.1 boundary, rejected direct acceptance, exact terminal sequence/revision/custody receipt, zero payment, retained resources and no replay checks remain unchanged. CourierFixture and the independent witness helper are untouched.

The binary-geometry method reads ShipCatalogue.nativeMesh for its native hulls. Mesh.hull intentionally substitutes the real-port MainStationGeometry for runtime station collision/rendering; the archival native catalogue retains SH028's original eight vertices and six faces. One source-only big-endian geometry calculation reproduces the existing station digest 7722a282e7859a2a2986ae5238b393575ba8cc957d593c97f2aacf695992b3c1 exactly. All seven original digest strings and every coordinate/face/detail encoding step remain unchanged. No runtime mesh or port change occurs.

Only the selected all-supported-items PLUGH method uses a new file-private initial SH023 shop factory. It preserves the original discovery, launch, arrival, docking and validity checks while choosing a hull with authored miningLaser/salvageCutter support before that journey. The generic plughGame helper and prerequisite-purchase helpers remain unchanged. Every actual discounted debit, paid predecessor, receipt count, mount, fuel, valid commander, ordinary-store reward restriction and naval-energy exclusivity assertion remains exact.

## Exact qualification selection

G1 owns matching compilation and these seven unparameterized methods / seven expanded cases; internal loops do not create additional case counts:

- pledgeCanReduceLegacyExcessFoodIntoTheActualPhysicalHold.
- pledgeRetainedBudgetNeverEvictsStandingOrReceipts.
- stationAutoMainPortFitsActualNormalizedCobraAcrossMatchedSpinStep.
- catalogueNpcGeometryUsesMeasuredRawVerticesAndNeverChangesThePlayerFit.
- rejectedDirectAcceptanceStillSettlesAnAlreadyExpiredCourierExactlyOnce.
- nativeShipFilesPreserveEveryOriginalCoordinateFaceAndDetail.
- plughShopSellsEverySupportedItemAtOneDiscountAndKeepsRewardsRestrictedElsewhere.

Strict scoped Swift formatting, Markdown lint, whitespace checks, original-assertion conservation, helper/default immutability and the independent archival digest calculation are author prerequisites. One coherent independent bugs/performance/style review is required. No author compiler, test, native probe, full CI replay or crash investigation ran. The first batch's passes must be retained separately by exact dependencies rather than repeated unnecessarily.

## Compatibility and remaining limits

No production, shared helper/default, TOML, resources, saved format, G05/G08 or first-batch test paths change. These valid initial fixtures supply no free equipment or resource refill during tested gameplay. Source-only prerequisites and review are distinct from actual qualification and final hosted acceptance. Existing failures remain preserved; no unrelated group, SIGBUS, full helper family or release completion is claimed. Companion: [ISSUE-hosted-native-prerequisites.md](ISSUE-hosted-native-prerequisites.md).

## Qualified second hosted prerequisite batch

Matching warm build1021 passes35.17native/36.98outer seconds. Actual1022 passes ONLY the seven new methods/seven cases in18.648native seconds (22.865runner/24.874supervisor), default Swift Testing6.4.0: all seven source declarations and terminals, no issues or unknown outcomes. All1,955 guarded artifacts, maintained inputs and primary preferences are exact; fourteen build starts and thirteen runtime starts independently absent, no timeout/cleanup, leases released. The first batch's seven methods/eight cases remain retained by exact four test files and all unchanged production/shared dependencies; they were not repeated.

All six owner test files and original numeric/geometry/digest/cargo/capacity/deadline/receipt oracles are exact, plus paired notes and one existing complete eight-path CLEAN review. Runtime proof `/tmp/elite-hosted-native-prereq-1022/event-stream-qualification.json`; closure `/tmp/elite-hosted-native-prereq-1022/guard-closure.json` SHA256 `3d98757e42e6d51eac5d98bcfc8b124dad2d523822ddc81f173293959bc88e6e`. These focused local results address eleven recorded hosted assertions without replacing the original failed run. Across both disjoint batches, aggregate14methods15cases have local passing evidence for28recorded hosted assertions; no single combined run or whole-suite acceptance is claimed. Hosted6.1/runtime/SIGBUS, global coverage/sanitizers/leaks, clean external review and release gates remain open. Test-only changes require no media/preview/review replay.
