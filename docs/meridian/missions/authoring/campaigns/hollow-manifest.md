# The Hollow Manifest

Private L337 proposal. Original story and design data; not installed or playable in the current app.

The cargo exists on paper. The danger is aboard a real ship.

A freight mutual is paying claims for industrial cargo that never left its warehouse. Reused seals make innocent captains appear responsible, while the true carrier transports unlisted refinery waste. The commander follows a physical seal through several freighters, rescues the carrier's stranded crew, recovers the original customs register and chooses public disclosure or a restitution tribunal. The witnesses are protected and the cargo fraud is resolved through evidence rather than revenge.

## Offer and reward

Speak to freight auditor Nia Toren at Narargan in Galaxy 2 after completing one normal commodity sale. No score gate or link to another campaign.

Payment: 5,600 CR, once on successful completion. Expense reimbursement is tracked separately; the selected public report or restitution fund appears in local gossip. Existing legal status is never reset. A permanent clue for The Unwritten Route: The inward mark.

## Briefing

Nia Toren: Two paid manifests name the same crate, and both captains insist it never reached them. Scan the freighters at Garrivek. If we follow the seal rather than the accusation, we can find where the cargo really went.

## Stages and dialogue

### 1. Narargan: accept

Accept the duplicate-manifest audit at Narargan.

TOREN: The mutual has paid for the same machinery twice. I want a complete custody record. Keep the captains alive and their original seals intact.

### 2. Garrivek: inspect-freighters

Scan the cargo seals on two consenting freighters at Garrivek.

Both seals are authentic, but their manufacturing scratches match. These are two impressions of one physical master, not two independent shipments.

### 3. Torenran: analyse-seals

Have the seals examined at Torenran and collect a loaned one-tonne inspection kit.

IVEN: The master seal was recalled. Someone retained it, stamped new dates and sent an empty carrier along the insured route. Take this scanner kit; it belongs to the laboratory.

### 4. Haldator: follow-carrier

Follow three cargo-handler wake marks to the hidden transfer cradle at Haldator.

The marks lead away from the station approach. The cradle accepted cargo that has no line in the carrier's declared manifest.

### 5. Durenran: recover-register

Recover the cradle's original custody register at Durenran.

The register lists sealed refinery waste. The machinery manifests were insurance cover for its transport. The carrier's crew were not told what their holds contained.

### 6. Haldator: rescue-crew

Guide the damaged carrier's evacuation launch to Haldator station.

The waste has overheated a service compartment. The evacuation launch carries the crew and its unaltered cargo log. Keep the route clear until station rescue accepts it.

### 7. Garrivek: reconstruct-ledger

Dock at Garrivek and reconcile the register, seals and rescued crew's log.

TOREN: The warehouse dates, recalled master and transfer register now agree. We can identify every false claim without inventing an accusation or silencing a witness.

### 8. Torenran: choose-remedy

Choose public disclosure or a crew restitution tribunal at Torenran.

IVEN: Publish the full ledger to stop new claims immediately, or lodge it with the restitution tribunal so the crews receive compensation first. The evidence is preserved in either case.

Choices:

- Publish the complete custody ledger
- Submit the case to the restitution tribunal

### 9. Narargan: return-equipment

Return the inspection kit and seal the remaining evidence at Narargan.

TOREN: The kit is back with the laboratory. The original seal and custody register will remain available to the crews.

### 10. Narargan: close-case

Confirm the fraud resolution and collect payment at Narargan.

TOREN: The false claims have stopped and the crew is safe. Your audit fee is 5,600 CR. Your own offences, if any, remain your responsibility.

TOREN: The master seal carried an older imprint beneath its serial number. It was never part of the freight register. Keep the image; the loops seem to point towards something missing from the middle.

## Completion clue

The inward mark: Beneath the recalled seal's ordinary signature is a second imprint: loops around an empty centre, with each loop pointing inward.

Every successful terminal grants this same permanent, zero-mass clue. All commanders collect the same 64 clues before decoding the trail at PLUGH.

## Interaction and recovery

Use the normal target and scan controls, contextual Confirm actions and mission contacts. Esc closes a dialog without accepting a transfer or choosing a branch. The mission log shows the current destination, target and next action. No special mission keyboard binding is introduced.

Mission equipment has its own reserved hold allocation and explicit acquire/return stage. Contacts retain the equipment when a transfer cannot proceed. Data evidence and completion clues occupy no hold space.

Persist each completed target. Recreate an uncompleted objective after load or entity loss; duplicate scans and incidental removal cannot complete it. Escort destruction returns to the escort briefing with a replacement launch and no reward.

Record the selected evidence/protocol outcome in pack state and gossip. Branches reconverge at the next stage and share the advertised base payment.

Every campaign starts unaccepted with its current identity and zero progress. Persist current-format stage evidence, choices, mission-item custody, reward and clue receipts. Resume these records on load; replayed events cannot duplicate rewards. No previous campaign or save format is imported.

## Implementation boundary

The TOML describes mission events, branch variants and receipts for future integration. [Engine contracts](ENGINE-CONTRACT.md) define the required event, item, escort and save behaviour. [Authorship record](ORIGINALITY.md) keeps the external research candidate separate from this original proposal.

## Artwork

![Mission briefing](../../../assets/missions/illustrations/hollow-manifest.png)

[Complete artwork gallery](https://github.com/stephenlclarke/elite/tree/6552b68f7a146ceb79b4376d33cc8afd3f987399). Every stage binds its own scene in the campaign TOML. Character portraits, evidence equipment and outcome images use the same current asset manifest.

- **Nia Toren:** [Portrait](../../../assets/missions/portraits/nia-toren.png)
- **Marek Iven:** [Portrait](../../../assets/missions/portraits/marek-iven.png)
