# Scriptable mission engine

## Problem and requested behavior

Schema 1 supports declarative story transitions but requires bespoke Swift for native mission mechanics. The owner requested implementation of the researched Lua/native engine design on a new branch, coordinated with the two coder sessions working on ships, charts, startup and controls.

## Scope

Keep legacy campaign IDs, saves and gameplay. Add a bounded C Lua host, explicit script state, verified immutable packs, native fact/transaction APIs, physical/custody/clock/campaign services, persistence and isolated Gallery acceptance. Retain space/orbital mission scope and all source/estimate distinctions.

## Acceptance

Complete the design's 24 requirement groups with actual native evidence, including Maenes, finance and RRS profiles; retain unsupported gates until then. Run `make ci`, sanitizer and leak checks. Publish Sonar only from committed main at its exact SHA. See [current implementation and remaining work](SCRIPTABLE-MISSIONS.md).

## Coordination

Engine branch: `feature/scriptable-mission-engine`, isolated checkout. Coder 1 owns geometry/appearance/charts and UX release; coder 2's startup/profit/controls/importer work is integrated there. Preserve their committed startup/profit additions when this branch integrates. No shared checkout edits or duplicate engine implementation are requested.
