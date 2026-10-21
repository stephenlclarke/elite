# Construct equipment display stock for the selected hull

The test helper now constructs ordinary starting stock from the selected hull's native performance before physical equipment initialization: at most 70 fuel units and three missiles. The original Cobra keeps 70 fuel and three missiles; the original Adder gets 70 fuel and one missile. Explicit preconditions require those starting values to fit the Commander's actual fuel and missile capacities.

All seven original test methods and their bodies, original ship/tool selection, both display sizes, owner/hull/item UUID generation and sorted Commander byte encoder remain unchanged. Production capacities, equipment migration, serialized counts and refusal rules are untouched. This is fixture construction, with no repair or normalization of loaded state.

Static inspection uses maintained TOMLs in the same filename order as `ShipCatalogue.load`. Source formatting, strict lint, scoped Markdown lint, whitespace checks and original-test-body preservation are the worker validation scope. Compilation and native test execution remain pending with the orchestrator, whose full CI run retains the canonical source lease. No native process, build, test or debugger is run by this worker. No GitHub issue or PR exists for this bounded repair yet. See [motivation](ISSUE-ownership-display-starting-stock.md).
