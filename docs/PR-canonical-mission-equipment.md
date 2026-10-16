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
