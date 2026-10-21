# RRS documents courier from a real station board

Native RRS docking now supplies sealed board, original-main destination and arrival contexts. A playable documents assignment must consume those contexts without treating an RRS station as a main orbital station or creating tradable cargo from a digital packet.

Implement base scenario 2 from Rescue Stations 1.5.4 only. Require RRS reputation at least -10, bounty at most 50 and the strict independent draw below 0.5. Retain a deterministic station/hour/profile board and one shared active RRS assignment. Explicit Confirm freezes the actual offering RRS station, the same-system living original main station and protected packet custody. Preview, Back and Decline grant no resources or packet.

Genuine arrival at the frozen original main station followed by debrief Confirm transfers the packet and pays 30.0 CR, reputation +2 and one completion. System departure, another galaxy, abandonment or actual destruction of that original main station records zero payment, reputation -10 and one failure. Temporary missing or unproved main-station evidence suspends delivery. Intermediate docking within the system remains allowed. No deadline, enemy wave, acceptance launch or refuelling is part of this assignment.

Use the existing candidate/save transaction spine, retain provenance and clock/epoch identities, validate Commander ownership on load and conserve the complete Commander, scene and previous files when the writer fails. Independent source review, actual runtime checks, maintained CI gates and the completed project PR review loop remain acceptance requirements. See [implementation handoff](PR-rrs-documents-courier.md).
