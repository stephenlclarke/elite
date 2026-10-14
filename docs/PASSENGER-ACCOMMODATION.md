# Common charter accommodation

This implementation adds actual saved humanoid passengers and uniquely owned cabin modules. It is a bounded common-project adapter, not the complete source-specific custody, rescue, medical-care or escape-pod engine. Historical missions requiring those other capabilities remain unavailable.

## Playing the demonstration

At Lave's main orbital station, open Equip Ship and select **Passenger Berth** in Passenger Accommodation. Return purchases and fits another cabin. Each cabin occupies **five tonnes of physical hold and one equipment unit**. The **1000 CR price is a project estimate**, with the existing Plugh shop discount applied once. The description labels the estimate. **S** stores one empty fitted cabin; **R** refits one owned stored cabin. Neither storage nor refitting charges again or creates a new module. Occupied, reserved or extra-crew cabins cannot be stored.

Install [scripted passengers](mission-packs/scripted-passengers), then accept through Mission Contacts. Ari boards an actual fitted empty berth at Lave. Fly to Zaonce's main orbital station and confirm delivery to receive 100 CR. Back leaves both the passenger and payment untouched. This is an original engine example, not a recovered historical mission.

The carried-fit comparison now shows operating crew, intrinsic crew quarters, fitted cabins, occupied/reserved places, free compatible places, cabin hold usage and spare freight hold. The existing shared preview orientation is unchanged. Hull transfer checks accommodation before confirmation; insufficient physical hold or equipment capacity blocks the exchange.

## Capacity and ownership

Operating crew counts include the commander. The selected `project-refit-v1` ship metadata supplies crew count, intrinsic quarters and equipment budget. The current compiled catalogue has 158 such profiles. Their existing source/borrowed/estimated status and basis remain in the ship TOMLs. Assigned operating quarters lie outside published usable cargo and are not subtracted again. Crew quarters and unfilled cargo space never become charter seats.

Only actually fitted, empty, compatible cabins with working life support count as free passenger places. Fitted cabins keep occupying hold and equipment capacity while empty. Stored cabins provide no capacity. Ordinary cargo, protected mission payloads and all fitted cabins share the hold. The unlimited-cargo cheat does not create physical passenger accommodation.

Laser controllers and missile pylons use their separate native constraints; intrinsic docking is excluded from the common equipment budget. Extra Energy Unit costs two units, Naval Energy Unit three, and native shield boosters two. Fuel-storage units and other hardware without a more specific selected common adapter use the documented **one-unit fitting estimate**. These are common-project costs, not a claim about native edition slots. Purchases with cabins fitted cannot exceed the combined budget; rejected purchases restore cash, equipment and shields.

People have native stable identities derived from mission instance, declared party and member index. A person retains the same cabin and owner through saves and missing content. Delivered people remain in a native receipt ledger at the destination. A repeated boarding operation cannot duplicate a person; a different operation ID cannot reissue an already boarded or delivered party. Required passenger objectives query actual native delivery, not script milestones.

Charter passengers cannot use the existing single-person emergency escape shortcut. It refuses while any fitted place is occupied or reserved. Actual occupied-pod evacuation, wreck survivors, damage/care jobs and environmental adapters still require the full custody engine; this adapter does not invent their outcomes.

## Author contract

Declare `charter-passengers-v2`, and list bounded `[[passengerParties]]` entries containing `id`, `names`, `pickupGalaxy`, `pickupSystem`, `destinationGalaxy` and `destinationSystem`. Locations use zero-based galaxy/system IDs, ordinary systems only. Parties contain 1–32 named humanoids; a pack has at most 64 parties and 128 people.

Use `passengers.board` or `passengers.deliver` with a once-only operation `id` and declared `party`. Native code checks the actual main orbital station, exact location, ownership, fitted places and whole transaction. `world.passengers` contains this instance's ordered native records with ID, party, name and location; aboard records include berth ID, delivered records include galaxy/system. `world.free_passenger_places` is the actual free fitted count. Neither snapshot can be edited to change custody.

Add party IDs to `mission.requiredPassengerParties` when their true delivery is a completion requirement. Completing all story milestones cannot substitute for those receipts. A later invalid command rolls back boarding, delivery, money and explicit script data together.

Saves with cabins or scripts publish format **5**, using the existing hashed immutable generation/pointer system. Readers accept earlier formats 2, 3 and 4; earlier physical writers reject format 5 instead of silently dropping passenger ownership. Keep the pointer and its `.missions` sidecar together. Automatic durable economic confirmation is a separate unfinished engine requirement; this checkpoint still requires an explicit commander save.

## Source-data follow-ups

The selected release catalogue still has the older zero-tonne SH128 player refit. Research verified a preferable twelve-tonne adaptation from [`oolite_template_transporter.max_cargo`](https://github.com/OoliteProject/oolite/blob/574ca848c91a067178416216523e8d09c1e9282a/Resources/Config/shipdata.plist). That source is an NPC capacity borrowed for the future player adaptation. It must enter through a separately validated data update, without changing release-pinned numeric profiles here. The current fit service uses the compiled value and does not silently substitute twelve tonnes.

Sunray, Minnow and Stingray research imports are also pending that data update. In particular, Sunray's first-acquisition cabin exception must become a uniquely owned, once-issued module when its native profile is imported. Repeated selection must never grant another free cabin. Native alien craft and drone identities do not authorize humanoid cabins or operating-crew assumptions.
