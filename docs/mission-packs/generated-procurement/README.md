# Generated procurement

This installable `PROJECT-SPACE-G03-1` pack covers procurement only. Food, Textiles or Machinery requirements are frozen at generation, with quantities of 1, 5 or 10 tonnes. Payment is the estimated 750/1500/2500 CR tier base plus 300 CR per frozen required hop. The native offer stores decicredits and settlement adds that stored amount exactly once.

Version 1.1.0 uses generator revision 2. Each tier filters the original ordered native routes to those whose minimum calendar cost is strictly below its existing two/two/three-day deadline, then selects using the original six route/commodity draws. If a required tier has no feasible route, generation refuses; there is no post-selection reroll or deadline extension. Revision-1 saved boards and jobs keep their original route proof and terms. Restoring an old job's exact installed content remains necessary for delivery; the current pack cannot replace its old content identity.

Use ordinary market acquisition and fly to the frozen destination main station. Actual positive material confirmations consume only outstanding sellable units. Earlier partial receipts survive reopening, saving and terminal expiry or abandonment. The final actual lot and current native contact authorize settlement; script flags and Lua payment requests do not.

The deadline uses the existing native mission clock: flight and actual launch/jump adjustments advance it; paused game and read-only menus do not. Final confirmation at the exact deadline is permitted. The existing native terminal resolver closes overdue jobs for zero payment without consuming remaining ordinary cargo.

The isolated Gallery scene starts in ordinary flight with its declared loadout. It does not fabricate a station arrival or accept a job. The player must actually dock, open the station board and Confirm. This pack is not added to the default library by this change.

Quantities, reward and deadline values are approved project estimates, not recovered server distributions. Supplied issuer-owned freight, generic protected Food/Textiles/Machinery custody, complete G03 acceptance and other generated families remain follow-ups.

The revision-2 correction has not been compiled or executed. Earlier qualified execution refused impossible-deadline revision-1 offers; it did not validate procurement delivery or Gallery acceptance. Native flight/market/docking fixture premises, publication failure/retry, focused coverage and `make ci` require the Orchestrator/G1 validation gate. Existing G02 golden terms, original nine procurement revision-1 goldens and literal collection/legacy deadline rules are retained.
