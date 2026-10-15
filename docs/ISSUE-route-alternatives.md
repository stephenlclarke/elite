# Graphical route alternatives on both charts

## Motivation

Route summaries need a graphical candidate preview so the player can compare paths before replacing an active plan. The short-range chart must show only its visible legs and explain offscreen continuation.

## Expected behavior

N opens alternatives on the chart in use. Up/Down or a candidate click changes the preview. Return or Set route commits; Back or Escape cancels while preserving the active plan. Routes remain manual travel instructions.

## Scope and compatibility

Retain the existing deduplicated Fewest Jumps, Safest, Trade Opportunities and qualifying Best Cargo Sale alternatives. Basic search radius is installed capacity in LY + 7, Advanced + 14, Military the whole current galaxy. First-leg reach uses actual fuel; later legs assume station refuelling and respect the fitted jump cap. No automatic jumps or save-schema changes are intended.

## Validation

Implemented and covered by focused route regressions, the integrated 284-test quality gates and native development/signed-app checks. See the [pull request handoff](PR-route-alternatives.md) for exact validation and remaining platform limits.
