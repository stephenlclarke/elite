# Profit bounds on valid native market inputs

## Motivation

CI955's profit-bound fixtures overwrite immutable native ask/bid quotes, making their Commander invalid. They then change asks even though carried-cargo valuation uses bids, so the intended positive and negative terms are absent. Their ranking destinations and economy-based tie also predate current world-keyed prices and reach.

## Bounded correction

Use authenticated original-world quotes and change only admitted stock and cargo counts. Independently derived integer witnesses preserve exact maximum/minimum saturation, cancellation to ten in both term orders, unsaturated ranking, stable ties and nonmutation. Assert quote identities, units, quantity bounds and valid Commander state before evaluating production results. No quote, catalogue, economy, production or test-hook change is permitted.

## Acceptance

Qualify the existing four methods and five cases on actual native inputs. Both opposing-order arguments remain. No earlier pass is retained for the changed private fixture. Companion: [PR-profit-authentic-market-witnesses.md](PR-profit-authentic-market-witnesses.md).
