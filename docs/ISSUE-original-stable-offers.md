# Stable Original station offers

## Motivation

Original contract boards currently use clock hours as generations. Waiting, returning to a menu or reloading can replace offered work without any native reservation or settlement. Offer identity should instead follow retained authoritative work from the exact provider and station.

## Scope

Use the existing cached revision as a durable floor and retained matching validated jobs as native evidence: acceptance advances past revision R to R+1; genuinely settled terminal work advances to R+2. Preserve cached listings during adoption, accepted terms, shared reservation limits and legacy hourly boards. No new persistent fields, schema, replenishment producer or Wayfarer adapter are included.

## Acceptance

Focused tests must cover time/reopen/pause, decline and page identity, actual admission and abandonment, stale/duplicate confirmation, failed writer rollback and current reload, source matching, checked overflow and legacy hourly behavior. Preserve the existing six-row disabled legacy courier regression. No flight or broad CI is part of this bounded owner qualification.

## Retention constraint

Current code retains boards and mission instances. Any future pruning must retain the generation floor before removing its board or job evidence. This change supplies no arbitrary archival guarantee or new stock producer.

## Links

Companion: [PR-original-stable-offers.md](PR-original-stable-offers.md). No remote issue or PR has been created.
