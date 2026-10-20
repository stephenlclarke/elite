# Profit bounds on valid native market inputs

## Motivation

CI955's profit-bound fixtures overwrite immutable native ask/bid quotes, making their Commander invalid. They then change asks even though carried-cargo valuation uses bids, so the intended positive and negative terms are absent. Their ranking destinations and economy-based tie also predate current world-keyed prices and reach.

## Bounded correction

Use authenticated original-world quotes and change only admitted stock and cargo counts. Independently derived integer witnesses preserve exact maximum/minimum saturation, cancellation to ten in both term orders, unsaturated ranking, stable ties and nonmutation. Assert quote identities, units, quantity bounds and valid Commander state before evaluating production results. No quote, catalogue, economy, production or test-hook change is permitted.

## Acceptance

Qualify the existing four methods and five cases on actual native inputs. Both opposing-order arguments remain. No earlier pass is retained for the changed private fixture. Companion: [PR-profit-authentic-market-witnesses.md](PR-profit-authentic-market-witnesses.md).

## Compile correction after candidate 967

The owner build stopped after 8.191 seconds because Swift Testing's macro type checker could not resolve the two inline tie-arithmetic requirements. No profit test ran. Extract each unchanged arithmetic expression into an explicitly typed `Int` local before requiring equality to `1_526_400`. Every literal, independent oracle and production-result assertion remains intact. The original compile failure is retained under `/tmp/elite-profit-compile-967`; the corrected child still requires matching compilation and the four-method/five-case owner run. No author build, test or native probe ran.
