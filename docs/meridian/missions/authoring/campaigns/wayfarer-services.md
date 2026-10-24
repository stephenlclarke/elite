# Wayfarer Exchange services

Private original proposal. Six repeatable service families continue after or alongside the induction campaign; no external source package is installed.

[Artwork gallery](https://github.com/stephenlclarke/elite/tree/6552b68f7a146ceb79b4376d33cc8afd3f987399) / [Service TOML](wayfarer-services.toml) / [Induction campaign](wayfarer-exchange.md)

## Board and accepting work

Use the existing station contract board. Show every destination, cargo/crew requirement, reward, actual deadline, integrity budget and hazard before Confirm. Esc changes nothing. At most three accepted contracts may reserve capacity at once. The board keeps the same quoted identities until a real stock or reservation event withdraws them. Closing the screen or loading never rolls new offers.

## Service families

### Cold-chain clinic service

Carry a sealed medical sample with an advertised integrity budget.

Player hold reservation: 1 t. Player passenger berths: 0.

Accredited for advanced or hazardous variants; ordinary variants show their own equipment/capacity conditions.

Independent quote: 320 CR base + 85 CR per reachable route leg + 90 CR per declared hazard tier.

Only explicitly quoted simulation-time deadlines. Pause stops the clock; saving preserves the remainder and does not reset it.

Preserve actual losses. A retry uses a new unique consignment from actual source stock and its own quote; no payment, restored cargo or induction clue from a failed instance.

Stages: collect, deliver, receive.

Grant this service family its own distinct permanent zero-mass clue on first verified successful reception. Repeat jobs retain it; never grant the induction clue or impersonate another family.

### Closed repair exchange

Carry an identified failed unit to its workshop and return the serviced unit to its registered owner.

Player hold reservation: 2 t. Player passenger berths: 0.

Accredited for advanced or hazardous variants; ordinary variants show their own equipment/capacity conditions.

Independent quote: 430 CR base + 90 CR per reachable route leg + 80 CR per declared hazard tier.

Only explicitly quoted simulation-time deadlines. Pause stops the clock; saving preserves the remainder and does not reset it.

Preserve actual losses. A retry uses a new unique consignment from actual source stock and its own quote; no payment, restored cargo or induction clue from a failed instance.

Stages: collect, service, receive.

Grant this service family its own distinct permanent zero-mass clue on first verified successful reception. Repeat jobs retain it; never grant the induction clue or impersonate another family.

### Seed-bank transfer

Transfer a consented seed consignment between independent custodians.

Player hold reservation: 3 t. Player passenger berths: 0.

Accredited for advanced or hazardous variants; ordinary variants show their own equipment/capacity conditions.

Independent quote: 510 CR base + 95 CR per reachable route leg + 110 CR per declared hazard tier.

Only explicitly quoted simulation-time deadlines. Pause stops the clock; saving preserves the remainder and does not reset it.

Preserve actual losses. A retry uses a new unique consignment from actual source stock and its own quote; no payment, restored cargo or induction clue from a failed instance.

Stages: collect, deliver, receive.

Grant this service family its own distinct permanent zero-mass clue on first verified successful reception. Repeat jobs retain it; never grant the induction clue or impersonate another family.

### Remote utility relief

Deliver actual repair materials to a remote utility receiving crew and verify their service handoff.

Player hold reservation: 4 t. Player passenger berths: 0.

Accredited for advanced or hazardous variants; ordinary variants show their own equipment/capacity conditions.

Independent quote: 610 CR base + 110 CR per reachable route leg + 120 CR per declared hazard tier.

Only explicitly quoted simulation-time deadlines. Pause stops the clock; saving preserves the remainder and does not reset it.

Preserve actual losses. A retry uses a new unique consignment from actual source stock and its own quote; no payment, restored cargo or induction clue from a failed instance.

Stages: collect, install, receive.

Grant this service family its own distinct permanent zero-mass clue on first verified successful reception. Repeat jobs retain it; never grant the induction clue or impersonate another family.

### Crew record recovery

Recover a specific flight/custody recorder without treating cargo wreckage as a living survivor.

Player hold reservation: 1 t. Player passenger berths: 0.

Accredited for advanced or hazardous variants; ordinary variants show their own equipment/capacity conditions.

Independent quote: 460 CR base + 95 CR per reachable route leg + 130 CR per declared hazard tier.

Only explicitly quoted simulation-time deadlines. Pause stops the clock; saving preserves the remainder and does not reset it.

Preserve actual losses. A retry uses a new unique consignment from actual source stock and its own quote; no payment, restored cargo or induction clue from a failed instance.

Stages: locate, recover, receive.

Grant this service family its own distinct permanent zero-mass clue on first verified successful reception. Repeat jobs retain it; never grant the induction clue or impersonate another family.

### Registered convoy watch

Escort the exact registered convoy and require the receiver's real cargo and arrival record.

Player hold reservation: 0 t. Player passenger berths: 0.

Accredited for advanced or hazardous variants; ordinary variants show their own equipment/capacity conditions.

Independent quote: 700 CR base + 120 CR per reachable route leg + 170 CR per declared hazard tier.

Only explicitly quoted simulation-time deadlines. Pause stops the clock; saving preserves the remainder and does not reset it.

Preserve actual losses. A retry uses a new unique consignment from actual source stock and its own quote; no payment, restored cargo or induction clue from a failed instance.

Stages: register, escort, receive.

Grant this service family its own distinct permanent zero-mass clue on first verified successful reception. Repeat jobs retain it; never grant the induction clue or impersonate another family.

## Custody and persistence

Reserve actual source stock and aggregate player capacity atomically. Pickup transfers the exact reserved consignment; the objective requires its verified service event; the named receiver then commits custody and payment once. Preserve late, spoiled and lost outcomes honestly. A canceled uncollected booking may release its actual reservation; a collected load cannot be refunded into source stock without physical return.

Cold-chain integrity is consumed only by armed flight simulation after pickup. Normal pause stops the budget and current-format save/load restores its remainder. Every service instance persists quote, source and target, consignment identity, quality, progress, reservations and payment receipt.

Induction accreditation and its PLUGH clue are awarded once by the main campaign. Each service family also grants its own distinct clue at first verified reception. Later jobs retain it and cannot impersonate induction or another family.

## Implementation boundary

These TOMLs and reference models describe original current-format content. Future authorised implementation must exercise real actor stock, cargo fitting, live crew, route generation, docking, escort identity, current saves and one-time payment before any runtime claim.
