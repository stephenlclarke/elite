# Bind the C08 pack's recorder to its authenticated historical model

## Behavior

The C08 recorder catalogue reference now selects NativeInductionCrewLogHistoricalGeometry.design before consulting the live showroom. The exact eligibility check requires the existing C08 stateID/version, the same model token and exactly one referencing NPC equal to NativeInductionCrewLogSource.recorderProfile. An extra use of the token as another NPC or component does not qualify. Other pack identities, versions, profiles and catalogue references keep the existing live lookup.

The resolver has no catch/fallback around the authenticated historical result. Script geometry/size validation, declared asset SHA/provenance checks and reference completeness remain unchanged. The historical reader, source hash, token, scale and fit do not change. ScriptPack digest construction and NativeInductionCrewLogPack.matches are byte unchanged; selecting geometry grants no actor, ownership, progress, payment or custody authority.

## Bounded implementation

Only NativeInductionCrewLogHistoricalGeometry's eligibility function and ScriptNPCAssets' catalogue resolution are production changes. The internal synchronous resolver accepts nonescaping live/historical readers so the focused tests can represent a future live Brabant and a real authentication failure without mutating global catalogues, creating public configuration or activating a hull. Production defaults use the existing ShipCatalogue lookup and cached authenticated historical Result. Asset reads and hashing remain pack-load operations; no per-frame work or new shared mutable state is introduced.

The retained resource remains the existing SH058.toml, byte-identical to original recorder commit61995c8c with SHA256 `6f5e4f8dc4a115ed833086199b853e8b5ec9baf1332a90bd44fa9c3d26a571d9`. Its canonical geometry hash and source/appearance are unchanged. Meridian `8c899a7e` defines a distinct live SH058 Brabant; its physical calibration and access are not borrowed from the historical recorder. Existing manifest/module/resource bytes and sorted model-key/canonical-design bytes remain the same for genuine C08, so its original digest must remain unchanged. A modified Lua or manifest still changes the digest or fails the existing full native guard.

## Focused units and source freeze

Four authored methods exercise the real bundled read/digest/hash/fit and unchanged parent custody, future live Brabant through the actual resolver while ordinary lookups retain their values, nine changed identity/profile cases with native pack refusal, and modified Lua content plus failed historical authentication with zero live fallback calls. These are load/fixture checks, not a native flight journey. The immutable-profile test technique uses existing Codable construction; no let property is mutated.

Base is prepared715 `914b312b79d963688df98b09476317bc742b85a0`, tree `80e5c7708076d257db5b3ebedd5d8ca9a67bb075`. This is an isolated source packet and does not amend that checkpoint. Strict Swift formatting, Markdown and whitespace checks pass; the four Swift methods are UNRUN and independent source review is pending. Selector/count files are deliberately unchanged until the actual qualified projected720 predecessor can be bound once, producing projected724 and one final hosted run. No719 run, local compiler/native/GUI/performance/probe or parent re-audit occurred. No publication is claimed.

See [the issue note](ISSUE-m04-c08-historical-loader.md). Other SH058 consumer dependencies and actual Brabant activation remain outside this packet.
