# Native crew custody and escape-pod rescue

## Scope and current status

This original native vertical slice implements source code for tracked occupied-pod rescue, captured crew, receiving care and explicit person sales. FR-005 and FR-006 are implemented as source candidates; they are not validated or released. G1 owns integration, actual electrical recovery, coverage/sanitizer/leak gates, PR review and protected merge. Generic medical treatment, hiring, rescue-station providers and the full R11 mission capability remain unfinished.

## Original crew and timing

Each person retains the original EMP source and ordinal. A pod's position in the archive is not its person's ordinal. Original people occupy exactly one census category: aboard, ejected, captured or deceased with their source hull. Selling, receiving care, player death and escape abandonment end player custody while preserving the original source discharge.

FR-017/018 supersede the earlier interpretation of FR-005 that capture happened after 30 seconds. Actual salvage contact before the recovery deadline captures original people still aboard, limited by actual free hold. The clock never transfers people to cargo. The working balance samples each surviving person's ejection delay once from the native seeded simulation RNG in 0.5 to 45 seconds at actual electrical zero. Recovery wins at 30 seconds; capture and ejection require an observation strictly before that deadline. Repeated partial EMP hits, target locks and partial cuts do not extend the episode. These bounds and tie rules are project balance choices, not quoted user percentages.

The permanent first incident is separate from the current disable episode. Up to 32 episodes retain bounded schedules, actual ejection times and physical binding history. Later episodes schedule survivors only. G1 implements actual electrical phases and validated traffic return for the same current actor, resources, pose, law, cargo and police assignment. The episode helper does not authorize recovery or restore an original NPC snapshot.

## Collection and hold accounting

The existing Salvage filter and Tab selection admit a proven native occupied pod to single-unit automatic scoop approach with a targeting core, fitted Salvage Module and Fuel Scoops. Collection requires the actual whole pod inside the existing scoop aperture with acceptable relative speed. Occupied pods remain orange independently of a full hold or missing tools; selection and collection still enforce those requirements. Foreign or protected occupants do not gain collection authority.

A sealed rescued pod occupies one protected tonne. Captured crew contribute once to actual Slaves cargo and retain separate original-person references. Five-tonne charter cabins and their fitted berths remain separate. Anonymous stock sales, cargo-removal commands, player death loot and hull changes cannot duplicate or silently erase held native people. One private, non-persisted capture seal joins current physical contact, actor, inventory, owner, hull, tool, revision and epoch. Full native publication happens before custody effects become live. A failed writer preserves post-physics world custody; explicit successful Save or actual interaction exit/re-entry permits another attempt.

## Station transfers and escape

Station Contracts reuses the existing typed review slot and immutable Commander snapshot. Back is the default. Care and named one-person sales need explicit native confirmation at a proved original main orbital station with current painted-page and sealed arrival evidence. Sales also recheck real cash, price and market stock. Receiving care ends player custody without a cure, reward or permanent station-population claim. History remains readable without current service authority, a writer or installed mission content.

Escape preserves occupied charter-berth and owned-equipment guards. Held native people receive a distinct original-ID escape/abandonment disposition in the same consumed-pod, courier-loss, cargo-clear and dock candidate. Screen and voice explain that people were left with the abandoned ship. This does not claim rescue or death and creates no new world capsules. A failed save restores equipment, cargo, original custody and controls through the existing actor command barrier. Player death uses the separate loss disposition.

## Save compatibility and Gallery

Any actual native custody, episode schedule or explicit deceased-ID archive selects schema 24. Reserved new fields, including present-null fields, are rejected in older headers and raw Commander input. Every new nested person, episode, binding and legacy-ejection collection is bounded before child decoding. Ordinary 21, EMP-only 22 and finance-only 23 remain valid when their actual new fields are absent.

An untouched legacy EMP archive retains its actual tags and absent fields. On real runtime upgrade, a marked legacy episode freezes the exact existing contiguous pod prefix and original next-ejection time. Old emission times remain unknown. Further legacy ejections use the existing one-second service and record their actual times; they cannot be falsely claimed as old history. A later genuine disable episode uses a new persisted random schedule for original survivors.

The original Gallery demonstration admits a real ordinary catalogue craft and fits actual owned tools. It begins with no disabled source, pod, captive or synthetic person ledger. EMP, tracked rescue, cutter capture and station transfer use native paths. Restart and return preserve the live commander and live files through existing isolated Gallery namespaces. Historical campaigns remain disabled.

## Validation required

Authored regressions cover physical collection, interleaved capture/ejection, exact deadlines, original-person census, real station doorway and confirmation, named sale, receiving care, stale input, blocked writers, equipment/people/controls escape rollback, cull/re-admission, version guards, poisoned nested arrays and Gallery isolation. These tests have not been compiled or executed by this source worker. Parser formatting and diff checks are source evidence only. G1 must integrate and validate the actual recovery/re-disable lifecycle, update older fixed-ejection fixtures, execute focused tests and full `make ci`, then complete clean `@codex review` cycles and final-head checks before protected merge.
