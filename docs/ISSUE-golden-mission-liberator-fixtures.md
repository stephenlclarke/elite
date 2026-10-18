# test: preserve current courier, mission and hull state through supported boundaries

## Motivation

The preserved review run 352 reports three stale fixture assumptions. The v1 golden courier is admitted through a real current save and runtime load, then passed to the legacy-only Commander loader, which rejects current drive and economy state. The mission migration fixture similarly tries the legacy loader a second time after its genuine first legacy admission has created current physical equipment and pinned mining state. Its seven recorded issues are second naval loads, with no recorded first-load or Blackjack assertion issues.

The Liberator fixture starts with raw equipment names and a rear Beam Laser. Real hull trade initializes physical owned equipment, including a standard Basic hyperspace drive, then mirrors fitted names. The recorded combined assertion shows preserved cargo and a changed name set. That projection does not establish lost owned hardware or a free paid upgrade.

## Required outcome

Continue the entire admitted courier Game and preserve every frozen v1 golden fact. Keep the genuine first legacy load for all seven naval and eight Blackjack stages, then use supported current publication for the second naval pass without replaying mission actions. Give the Liberator fixture real owned hardware before recording its preservation oracle and check the complete portable property across exchange. Existing gameplay, reward, cargo, mission, fuel, ammunition, material and flight checks must remain.

## Scope and risks

Only three existing test methods and paired documentation change. No production code, golden fixture, guards, schema, pricing or physics changes are required. These are three Swift Testing cases; the fifteen internal mission-stage iterations remain part of one case. Runtime validation remains pending source review and integration. See the [pull request record](PR-golden-mission-liberator-fixtures.md).
