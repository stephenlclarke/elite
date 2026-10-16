# Canonical mission equipment composition

## Motivation

Mission-issued devices and finite player missiles need one physical owner, preserved original identities and enforceable loan obligations throughout native and Script actions.

## Shared schema checkpoint

The first checkpoint adds typed mission acquisition provenance, retained legacy device metadata, one displacement reference type, immutable issue/budget/obligation contracts, explicit physical or virtual player ammunition sources, and a single-revision atomic inventory batch. Copy paths preserve metadata. Standard ammunition exposes only the active hull's real missile pylons, and damaged or modified legacy items remain held. Existing saves and attack origins decode with absent optional fields.

Quote and receipt types belong exclusively to their transaction provider files, where constructors can be sealed. This checkpoint supplies no placeholder provider and does not activate Commander version 2. Its explicit version-1 guard prevents partial native admission while migration and consumers are still being composed.

## Validation

Six focused schema regressions cover metadata preservation and round trips, old decode compatibility, atomic revisions and refusals, malformed provenance and held legacy condition, actual pylon capabilities and migration-only absence constraints. At this checkpoint they are authored, not executed: the shared validation lease is running the separate central repair candidate. Source formatting and parsing are checked separately and are not runtime acceptance.

## Compatibility and remaining work

The final implementation must add sealed issue and ammunition transactions, once-only Commander migration, native inventory/shop/ordnance and consumable adapters, reciprocal Script issue validation, Gallery lifecycle fixes and actual-reach courier generation. It must preserve format 21 and the current production save. Full validation, formal review, main-only SonarQube analysis and release remain outstanding. See [the issue record](ISSUE-canonical-mission-equipment.md).

## Version-2 native migration work

The next source checkpoint imports the version-1 finite missile counter once while preserving existing owner, hull, physical item identities and purchase-history revision. Legacy initialization creates the actual rounds at real pylons. Version-2 saves require the persisted missile mirror to match fitted physical rounds; an empty rack stays empty and mismatches reject the whole load. Native missile purchases use the paid physical inventory transaction with one revision, and inventory offers real vacant pylons. Unlimited supply toggles preserve finite rounds; explicit maximum-hardware grants fill vacant pylons while preserving held devices.

Six additional migration and native purchase regressions are authored but not executed. The physical firing, native consumable and reciprocal Script adapters are still being composed; this intermediate branch is not a playable or release-qualified version-2 build.

## Native physical consumption work

Player missile launch stages the sealed ammunition application, exact removed-item mission delta, existing `gear.consumed` event, explicit immutable ammunition source, projectile admission and combat allocators on one copied Game. A refused launch publishes none of those changes. Energy bombs, escape pods and galactic drives use exact throwing physical consumable applications, preserving held spares. Event capacity refuses consumption rather than dropping a required event. Unlimited launches preserve finite inventory and its revision.

Three actual native launch regressions and the revised concurrent shop boundary regression are authored but unexecuted. These source adapters depend on the MC1 Script state/event seams and G2 sealed providers, which are not yet imported into this checkout. Parsing and formatting are source checks only; this checkpoint is not a complete build.

## Legacy mission save admission work

Commander retains the old `ownedEquipment` JSON key solely as a legacy read DTO, with explicit coding keys for all stored fields. Script state retains the accepted modify accessor and empty-state defaults; contracts and accommodation remain optional persisted fields. Old bag mirrors and reciprocal issue rights validate before conversion. Migration preserves original ordered UUIDs, source indices, held condition and modifications, emits canonical version 2 once and removes the old bag. Genuinely implicit Basic shield, energy and navigation foundations are materialized only for vacant systems or an active issued replacement, with actual retained displacement references. Historical nonloan absence receives only the bounded migration marker and never fabricated consumption or a replacement original. Mixed representations refuse atomically.

Checked cargo arithmetic validates Script payload quantities and collection bounds before adding them, then includes actual fitted cabins with checked operations. Five authored legacy migration and payload regressions cover the old JSON key, metadata and empty missiles, retained loan restoration, historical absence, substitution/mixed-state refusal and extreme payload admission. They remain unexecuted until the full engine and native consumers are composed. The pure engine import follows the immutable path manifest and retains original Lua vendor bytes and licenses; upstream blank lines are not authored C changes. Four original bag-based test files await MC1 canonical replacements before any build.

## Native issued fitting and custody work

Native fitting and storage of active issued devices use the sealed issue provider, actual projected accommodation budget and retained Script receipt application together. This includes held loan missiles and active nonloan issues. Native previews reuse their already captured context as a discarded planning binding; actual user actions allocate one fresh command. Personal missile loading uses the standard ammunition provider. Foreign active loan occupants cannot be displaced by personal fitting, shop replacements or hardware grants, and active loans cannot be graded or erased through generic removal.

Five native regressions are authored, not executed: loan-round fitting/storage, exact personal laser restoration after native refit and return, foreign-loan refusal, repeated unchanged previews, and an actual Commander hull transfer followed by mission settlement. The transfer regression uses the native transfer operation and Script settlement adapter to verify the same personal UUID, component, provenance and metadata return to the compatible new hull while the original displacement evidence remains unchanged. The composition still awaits remaining engine/core lifecycle hooks and a dedicated validation lease.

## Actor and native storage composition

Game now retains accepted mission, conversation, trial, contract-board and library value state. The simulation actor stages mission-aware user commands and typed equipment transactions with a single publication barrier; physical frame effects remain authoritative before autonomous mission proposals. Mission calendars activate only through the shared actual-feature predicate, preserving ordinary direct Commander JSON saves. An actual old-bag admission explicitly retains the existing calendar marker after removing the old bag.

Save and load remain synchronous actor operations in the existing ordered native input stream. The native persistence preparation remains shared with chunk storage, Gallery path restrictions apply, and loads stage the complete candidate before changing its active writer or controls. Raw input uses the bounded opened-file reader. Typed missile combat is retained; only optional Script actor/shot descriptor fields were added to SpaceBody.

Four actor compatibility regressions are authored but unexecuted: ordinary init/flight/direct JSON, retained empty calendar/version 21 round trip, failed publication rollback of an actual missile purchase, and failed load preserving the active writer and full state. This checkpoint depends on MC1 shared activation/persistence and typed-world bridge pins plus the separately owned UI hooks; it is not yet build-qualified.

## Physical scene and calendar hooks

Native launch, docking and arrival preserve existing cargo, ore, salvage and NPC settlement barriers while retaining Script actors at successful scene transitions and before camera culling. Calendar entry is guarded by actual mission durability; admitted journeys retain the actual graded native fuel debit and frozen destination. Ordinary launch creates no calendar. Reserved passenger cabins refuse escape without consuming the pod, and courier loss is staged with a successful escape. Trading retains the accepted physical accommodation capacity while preserving the overflow-safe route score.

Script-owned actors are tagged and protected before ordinary NPC persistence can adopt them. Their flight profile runs after the actual native camera, with ordinary legacy steering and naval tactics excluded. Legacy ECM/removal and missile fallbacks exclude authored Script shots. A retained station frame is projected through the one canonical before/after camera pose for both manual motion and in-system jumps. No old direct Script damage or separate native allocator was imported; typed weapon and cross-visit world bridges remain pending their reviewed implementation pins.

Seven authored scene regressions cover ordinary/calendar launch, launch refusal, actual graded frozen travel, passenger escape refusal, mission adoption protection, and world-point invariance through actual manual flight and in-system jump. All remain unexecuted until the complete source dependency set and dedicated composition validation are ready.
