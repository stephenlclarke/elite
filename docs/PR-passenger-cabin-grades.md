# feat(passengers): fit graded cabins with individual passenger places

Purchase a complete 5t cabin containing twenty packed stasis places, eight economy places, four standard places, two luxury places, or a single/double stateroom. Every module consumes one equipment unit; occupancy does not change its footprint. Fixed cabin, place and person identities preserve custody, reservations and receipts across fitting, current saves and compatible hull exchange. Read-only quotes allocate no property identities. Historical native offers retain immutable grade/layout snapshots after genuine property loss; still-owned layouts must agree with those snapshots.

Explicit party transport-mode declarations permit stasis boarding. Existing native passengers keep awake/private-cabin promises, including Outlook: two places in one physical cabin do not satisfy two private cabins. Private reservations block all remaining places. Broken required hardware, stale quotes, insufficient fit or failed durable writes publish no purchase/custody/debit. The shop and showroom distinguish cabins, places and people; generated ship basis labels describe per-module mass. Prices and intermediate capacities are initial project balance defaults.

## Validation

MBA source formatting/strict lint, generated-basis parity, bounded identity/cargo consumer inspection, ASCII, Markdown and exact owned-path checks are recorded in the freeze packet. No author compiler/native test/CI job runs. G1 owner compilation and focused execution are pending after M01 publication. Full independent review follows actual focused owner PASS, then G1 integration; this note claims no native or release acceptance.

## Focused owner selectors

New focused methods in PassengerCabinGradesTests cover twenty distinct people and actual delivery, person21/awake-only refusal, every grade's two fitting budgets independent of occupancy, private reservations versus shared double stateroom, hardware and saved transport consent, current-save layout/identity rejection, durable actor writer/stale-quote refusal, and hull-transfer identity/refusal. NativeOrbitalOutlookJourneyTests adds outlookPrivateAwakeConsentRejectsPackedPodsAndTwoPlacesInOnePhysicalCabin through actual paid actor purchases and native replies/boarding.

Retain affected ShipAccommodationTests, PassengerCustodyTests, NativePassengerCabinViewTests, NativeStationPassengerJourneyTests, NativeOriginalRescueJourneyTests, NativeOriginalEvacuationTests and OwnedEquipmentHullTests controls selected from final changed paths. The source-only owner inventory has 49 methods / 59 statically expected cases: primary feature11/12, changed fitting/actor/cargo/display/save/transfer consumers28/29, actual native consent/save/loss controls10/18. Compile all changed fixtures, run primary cases first, then affected consumers and native controls. These counts are planned cases, not executed results. No broad unrelated suite replay is proposed. Exact selectors accompany freeze.

## Compatibility and risk

The current cabin save shape changes deliberately without backwards decoding or migration. Existing operating crew quarters remain intrinsic and outside these cargo modules. Native/person/save/actor integration must qualify as one coherent change; source checks do not establish behavior or performance. Paired issue: docs/ISSUE-passenger-cabin-grades.md. No PR has been created by this author.

## Compiler-only correction

Actual matching build 1269 compilation rejects the optional berth.map closure because it captures borrowed Commander in NativeOriginalRescueJourney.replyToTransportOffer. The raw build evidence is retained at /tmp/elite-FR058-cabin-build-1269/build.log, SHA256 8707838e33dc7c4f7f4defc90b1c4ffebd8669b43e13ae6839e871822a1e5ac0. No tests ran on that rejected build.

The child replaces only that predicate with a private optional-place helper taking borrowing Commander at the same short-circuit position. Nil returns false; working awake support is checked before private-cabin status in the original order. No owned Commander copy, moved predicate evaluation, state/storage/schema/authority change or test selection change is introduced. Parent 6694b3821a04b069ce2b2c6617da3e16ef4e883d remains immutable. Whole-source inverse and the other 205 parent feature blobs are verified; source checks do not establish compiler success. G1 owns a fresh matching compilation, then the unchanged primary 11-method/12-case cohort before remaining focused qualification and full independent review.
