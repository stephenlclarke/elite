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
