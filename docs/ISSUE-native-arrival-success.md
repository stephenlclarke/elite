# Require explicit native arrival success

## Problem

The native arrival implementation can defer without throwing when a wreck settlement remains pending or salvage persistence refuses. A caller that only checks for an exception can treat that soft refusal as completed arrival. In the private galactic-jump transaction, that would allow fuel refill and successful publication after the native arrival declined to proceed.

## Required result

Return an explicit success result from native arrival. Both ordinary arrival and galactic jump must require success before publishing their candidate. Ordinary deferred messages and countdown cancellation remain visible without turning a soft refusal into a paused exception path. Preserve active-projectile preflight and the existing outer transaction.

Define regressions using actual generated/admitted native wrecks for both existing soft-refusal causes, preserving the original drive, fuel, cargo, flight and wreck custody. Also verify an actual successful galactic jump through its new native flight system, anchors, player visit and real main-station body, rather than checking only the Commander galaxy value.

## Validation boundary

This bounded correction is a child of frozen lifecycle source `22f2174e235fa8fb17b614569efe54d340b6874b`. Only Game arrival result/callers, the owned Crimbo runtime test file and this issue/PR pair change. Compiler/test/native execution remains with G1. See [implementation details](PR-native-arrival-success.md). Eventual project PRs require completed clean `@codex review` cycles and final-head required checks before protected merge.
