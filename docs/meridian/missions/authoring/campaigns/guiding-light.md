# The Guiding Light

Private L337 proposal. Original story and design data; not installed or playable in the current app.

RENN: A lantern outside your line of sight is not a safe approach marker.

Crimbo's winter orbital services depend on a chain of navigation lanterns whose light-sharing contract does not account for the planet's long shadow. A maintenance crew has been routed to an unlit receiving pier. The commander measures the actual horizon, restores physical relays and escorts the crew before choosing independently maintained lantern segments or a shared winter rota.

## Offer and reward

At Crimbo in Galaxy 8, after one ordinary trade. No imported score gate or source campaign prerequisite. The reference loan needs one tonne of free hold.

Payment: 5,700 CR, once on successful completion. The selected verified settlement persists in local records. No free hull, unrelated legal reset or artificial combat kills. A permanent clue for The Unwritten Route: The extra lantern.

## Briefing

RENN: A lantern outside your line of sight is not a safe approach marker.

## Stages and dialogue

### 1. Crimbo: accept

Accept The Guiding Light at Crimbo.

Dispatcher Evi Senn: Crimbo's winter orbital services depend on a chain of navigation lanterns whose light-sharing contract does not account for the planet's long shadow. Review the complete survey, loan and receiving requirements before confirming.

### 2. Crimbo: survey

Measure three winter-shadow lantern sight lines at Crimbo's orbital relays.

RENN: A lantern outside your line of sight is not a safe approach marker.

### 3. Crimbo: collect-reference

Collect the identified one-tonne reference instrument from Dispatcher Evi Senn.

Dispatcher Evi Senn: This instrument is a loan. I retain it until your hold has room, and the final audit returns this exact serial identity.

### 4. Crimbo: field-work

Restore two external winter relays using the reference lantern.

SENN: Record their real receiving acknowledgements before advertising the lane.

### 5. Crimbo: independent-witness

Escort the consenting maintenance tender to the now-lit winter service berth.

RENN: Keep the lanterns visible through the final approach; a distant signal alone does not receive a crew.

### 6. Crimbo: choose-settlement

Choose the verified settlement with the consenting operators.

Dispatcher Evi Senn: Both choices preserve the independent evidence. Choose who controls the future work; closing this dialog selects neither.

Choices:

- Maintain independent winter lantern segments
- Publish a jointly maintained winter rota

### 7. Crimbo: apply-settlement

Verify both independent proofs for the selected settlement.

Dispatcher Evi Senn: The selected plan must work in the physical system. A statement or unrelated kill cannot supply either proof.

**plan-a:** Verify both local maintenance receipts and the overlapping safe horizon.

RENN: Each segment has to see the next before it can guide a traveller.

Gossip: The Guiding Light: Maintain independent winter lantern segments.

**plan-b:** Verify the signed rota and a real shadow-side receiving test.

SENN: A shared schedule needs an actual crew behind its next shift.

Gossip: The Guiding Light: Publish a jointly maintained winter rota.

### 8. Crimbo: return-and-audit

Return the reference instrument and confirm all physical receiving and settlement receipts.

Dispatcher Evi Senn: The loan is returned. Check the actual observations, living witness reception and both selected settlement proofs before closing the case.

### 9. Crimbo: close-case

Confirm successful completion, the recorded settlement and the once-only fee.

Dispatcher Evi Senn: The independent audit is complete. Your fee is 5700 CR. The operators retain the chosen settlement and their original records.

Dispatcher Evi Senn: The audit has left one anomaly that belongs to neither side. The verified winter relay record preserves one extra inward-moving lantern phase absent from the physical array. It is preserved in your journal for the AI at PLUGH.

## Completion clue

The extra lantern: The verified winter relay record preserves one extra inward-moving lantern phase absent from the physical array.

Every successful terminal grants this same permanent, zero-mass clue. All commanders collect the same 64 clues before decoding the trail at PLUGH.

## Interaction and recovery

Use the normal target and scan controls, contextual Confirm actions and mission contacts. Esc closes a dialog without accepting a transfer or choosing a branch. The mission log shows the current destination, target and next action. No special mission keyboard binding is introduced.

Use the existing mission log, targeting, scan, contextual Confirm and Esc. Preview all obligations before accepting; cancellation changes nothing.

Keep the reference instrument in reserved custody through the field work, witness reception and selected settlement. Returning it is part of the independent terminal audit.

Preserve actual crew and entity identities. Culling is not death or arrival. A lost unnamed tender may be replaced with a new consenting crew after real rescue handling; never resurrect a named casualty. A lost reference invalidates its old serial before a real replacement loan.

All objectives are space flight or space-station handoffs. Stations remain protected from single-ship weapons. No source world overrides, equipment budgets, hidden reputation grind or external storyline progress is required.

Persist each completed target. Recreate an uncompleted objective after load or entity loss; duplicate scans and incidental removal cannot complete it. Escort destruction returns to the escort briefing with a replacement launch and no reward.

Store the selected plan-a or plan-b identity once, separately from its authored display label. Apply only that branch at apply-settlement; both distinct physical and receiving proofs are required. Both legitimate endings share one final reward and one source clue.

Every campaign starts unaccepted with its current identity and zero progress. Persist current-format stage evidence, choices, mission-item custody, reward and clue receipts. Resume these records on load; replayed events cannot duplicate rewards. No previous campaign or save format is imported.

## Implementation boundary

The TOML describes mission events, branch variants and receipts for future integration. [Engine contracts](ENGINE-CONTRACT.md) define the required event, item, escort and save behaviour. [Authorship record](ORIGINALITY.md) keeps the external research candidate separate from this original proposal.

## Artwork

![Mission briefing](../../../assets/missions/illustrations/guiding-light.png)

[Complete artwork gallery](https://github.com/stephenlclarke/elite/tree/6552b68f7a146ceb79b4376d33cc8afd3f987399). Every stage binds its own scene in the campaign TOML. Character portraits, evidence equipment and outcome images use the same current asset manifest.

- **Dispatcher Evi Senn:** [Portrait](../../../assets/missions/portraits/evi-senn.png)
- **Relay Engineer Ivo Renn:** [Portrait](../../../assets/missions/portraits/ivo-renn.png)
