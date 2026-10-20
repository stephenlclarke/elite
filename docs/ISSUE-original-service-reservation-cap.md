# Shared Original contract and Wayfarer reservation capacity

## Problem

Original contracts and native Wayfarer services must share at most three active accepted reservations. Provider-specific limits alone permit the combined total to exceed three. This existing M05/M09 prerequisite blocks MBA06 default Wayfarer publication.

## Required behavior

Derive occupancy from current accepted contract jobs in the Original contract or Wayfarer service namespace and from native Wayfarer custody, counting each active instance once. Exclude legacy project couriers and campaign or story instances without accepted jobs or native custody. Complete, failed and abandoned instances release a slot. A fourth quote or confirmation must refuse before payment, custody or publication. Current-save validation must reject an over-cap container without adding saved fields or another reservation ledger.

## Scope

Four existing admission/validation files, one small shared policy, one focused test file and paired notes are reserved. Preserve provider-specific restrictions, stale-quote checks, idempotent confirmation, existing writer rollback and existing save versions. No flight, docking, Game, Director, renderer, clock or mission-content change. MBA03 native-flow qualification remains separate and its original frozen packet is preserved; MBA07 consent implementation remains unapproved.

## Acceptance

Owner focused unit tests must pass, followed by independent bugs/performance/style review before G1 integration. No GitHub issue or PR number is assigned. Broad CI, sanitizer, leak, release and protected PR gates remain separate integration requirements.

## Owner status

Six focused methods/six cases are qualified in aggregate, retaining five unchanged passes and one corrected cancellation pass. G1 independent bugs/performance/style review completed CLEAN with no findings before integration. This prerequisite does not complete whole M05/M09 playability or publish MBA06 content.
