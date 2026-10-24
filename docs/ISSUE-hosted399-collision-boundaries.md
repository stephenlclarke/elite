# Component geometry measurement must target the selected hull

## Actual failure and scope

Hosted39943 recorded a component-geometry miss assertion because the measurement helper queried the populated scene and returned an unrelated rescue station. The five measuredNPCContact calls all belong to componentRayHitsUseMeasuredGeometryAndCannotBecomeHullDeathOrPlayerBounty and must query that actual target. Actual native contact application, allied laser evidence, destruction and no-player-bounty checks remain independent.

This integration includes only ScriptNPCTests.swift. The separately reviewed station pressure diagnostic was exercised in the same bounded run but failed: an actual nearby Viper was first contact. That station source remains isolated for Root's separately assigned correction. No production collision change follows from either fixture result. See [qualification](PR-hosted399-collision-boundaries.md).
