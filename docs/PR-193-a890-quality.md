# Pr 193: Make combat fixture cash and resource baselines explicit

## Motivation

Required quality run [40062040085](https://github.com/stephenlclarke/elite/actions/runs/40062040085) at `a890a93c7e7d698fd8a308cbb39dad75fe892278` completed3395normal methods with99issue records across55distinct methods. All1879retained source/build inputs match the published head. The helper exited naturally with status1; no SIGBUS recurred. Coverage execution failed, so later sanitizer and leak gates were not established.

## Bounded correction and preserved behavior

combatGame constructs current Game without setting the1000 cash baseline assumed by11methods. Current approved fresh cash differs. Explicitly select the intended compatible hull, valid fuel/fit, cash and shield/energy baseline in this helper, or derive independent pre-action values where the contract is relative. Police test314 specifically assumes250/256 after5damage. Preserve legal, bounty, victim, shield order and kill assertions; do not alter approved fresh defaults.

This is one cause group in the single M01 correction packet, not a separate execution or review gate. Confirmed fixture changes explicitly establish their intended hull stock, cash, shop eligibility, authored world or codec envelope. The corrections retain their original behavioral assertions and bounded failure-only facts; the retained receipts establish their actual causes and scoped results. The physical runner arrangement retains the hard GPU assertions and every required quality command; [its authorization design](NATIVE-QUALITY-RUNNER.md) keeps untrusted events and unapproved heads out of native execution.

Affected methods:

- `lawfulPoliceFireOnWantedPlayerInsideStationZoneDoesNotCreateRoguePolice()`
- `npcAssaultAttributesLegalDamageAndDefenceToItsActualVictimWithoutPlayerCredit()`
- `absentOriginalNPCShooterStillOwnsMissileDamageAndPlayerShieldsApplyInOrder()`
- `cleanHitIsRecordedBeforeRetaliationAndMurderGetsNoHostileBounty()`
- `knownBountyAndImmediateDefenceCreditOneKillAndRankChange(_:)`
- `interceptedOrdnanceNeverBecomesAShipKillOrBounty()`
- `policeAndInvulnerableStationUseSpecialisedPenaltiesAndVerifiedAlarm()`
- `targetedMissileChargesBeforeDamageAndKeepsItsOriginalVictimEvidenceUntilImpact()`
- `matchedActiveMissionUsesItsSourceRewardWithoutDispatchingRemovalEvents(_:)`
- `navalBombImmunityAndExplicitHuntEntitlementStaySeparateFromHullBounty()`
- `onlyMiningLaserExtractionPublishesOreFromTheActuallyHitRock(_:)`

## Validation and compatibility

The combined correction packet has independent source reviews and scoped executed results. Every original failing method (55 unique methods from 99 issue records) now has an individual passing result, with 12 additional direct consumers retained across the bounded follow-ups. This is a reconciled set of scoped passes, not a fresh aggregate full-suite run. The 14 native-runner fake units and both hard GPU methods also pass. The [combined focused receipt](evidence/M01-bb85-focused-qualification.json), [independent retained inventory](evidence/M01-bb85-retained-qualification-inventory.json) and [last four-phase save result](evidence/M01-bb85-terminal-verification.json) preserve source identity and limits. Final published-head checks, full `make ci`, committed-main SonarQube and release acceptance remain required. No issue closure or full quality/release pass is claimed.

## Links and remaining risks

[Issue 193](https://github.com/stephenlclarke/elite/issues/193); [PR25](https://github.com/stephenlclarke/elite/pull/25). Focused owner qualification is complete; Full final-head quality, protected merge, committed-main-only SonarQube with exact source SHA and signed/notarized release acceptance remain required. Issue185 stays open pending full quality; this terminal run is not a recurring stack crash.
