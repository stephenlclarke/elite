# A Choir Beneath the Static

Private L337 proposal. Original story and design data; not installed or playable in the current app.

A signal mistaken for a weapon may be a request for help.

Mining navigation receivers in Quiet Current are being drowned by repeating Larvaal phase pulses. The pulses contain synchronized gaps, not firing orders. A damaged Larvaal Probe has been trying to locate its dispersed companions while human smugglers imitate the signal to conceal their own traffic. The commander reconstructs the pulses, repairs the probe, exposes the imitation and negotiates a narrow-band rendezvous that lets both fleets navigate safely.

## Offer and reward

After identifying a Larvaal vessel and visiting four systems, speak to Holt at Omdogan in Galaxy 4. This campaign is independent of The Glass Meridian.

Payment: 6,400 CR, once on successful completion. A resonance-filter fitting, improving identification of this campaign's Larvaal signals. It grants no extra energy capacity, general faction immunity or free ship fabrication. A permanent clue for The Unwritten Route: The silent voice.

## Briefing

Captain Tamsin Holt: No one has proved these pulses are an attack. Calibrate your receiver at Lobagom before approaching the source. Agent Mara Vale will compare what you find with the mining relays.

## Stages and dialogue

### 1. Omdogan: accept

Accept Holt's signal investigation at Omdogan.

HOLT: Our miners are losing their bearings. I will not order an attack on the basis of interference. Find out whether someone is calling, warning or hiding.

### 2. Lobagom: calibrate

Scan three reference emitters at Lobagom to separate receiver drift from outside interference.

The receiver is stable. The interference contains a deliberate pause after every third pulse, repeated across all three bands.

### 3. Lodogom: recover-collector

Recover a one-tonne phase collector from the damaged mining relay at Lodogom.

A passive collector has recorded the missing phase information. The relay is dead, but its sealed recorder can be recovered without disabling any ship.

### 4. Balmabol: interpret

Dock at Balmabol and let Mara Vale reconstruct the signal.

VALE: This is a gathering call. Each pause leaves room for a reply from a missing companion. Someone has copied the loud part and omitted the listening interval.

### 5. Balgodan: repair-probe

Deliver the loaned repair culture to the stranded Larvaal Probe at Balgodan.

The jade shell opens around the damaged resonator. The repair culture bridges a broken fold; the probe answers with a short gold pulse.

### 6. Dalonom: listen

Listen at three safe positions around the Larvaal gathering at Dalonom.

Three listening positions reveal an empty place in the call. The missing voice should be near Fobolan, where the repeated signal never pauses.

### 7. Fobolan: expose-imitation

Locate and silence the counterfeit emitter at Fobolan.

Human freight seals surround the emitter. Present its copied certificate to make the smugglers abandon it, or disable the exposed transmitter. Destroying unrelated ships proves nothing.

Choices:

- Broadcast the forged certificate and demand shutdown
- Disable the unmanned transmitter

### 8. Omdogan: rendezvous

Transmit the corrected reply at Omdogan and choose a rendezvous protocol.

VALE: We can publish the narrow-band greeting for civilian receivers, or establish a supervised relay while both sides learn its limits.

Choices:

- Publish the civilian greeting
- Establish a supervised listening relay

### 9. Omdogan: close-case

Dock at Omdogan and confirm the completed signal accord.

HOLT: The miners have clean guidance channels. The Larvaal vessels have a safe gathering frequency. Your fee is 6,400 CR; the passive resonance filter is ready for fitting.

VALE: One voice answered from outside the gathering. The Larvaal listeners do not recognise it. Its pauses form a pattern like a map. I have preserved the reply in your journal.

## Completion clue

The silent voice: The restored Larvaal call contains a reply from beyond the gathering. Its pauses describe a curve, but no Larvaal vessel claims the voice.

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

![Mission briefing](../../../assets/missions/illustrations/quiet-choir.png)

[Complete artwork gallery](https://github.com/stephenlclarke/elite/tree/6552b68f7a146ceb79b4376d33cc8afd3f987399). Every stage binds its own scene in the campaign TOML. Character portraits, evidence equipment and outcome images use the same current asset manifest.

- **Captain Tamsin Holt:** [Portrait](../../../assets/missions/portraits/tamsin-holt.png)
- **Agent Mara Vale:** [Portrait](../../../assets/missions/portraits/mara-vale.png)
