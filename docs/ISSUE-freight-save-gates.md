# Freight save envelope boundaries

Issuer-owned freight needs its custody, generated offers and board generation stored together with the native world. A raw Commander or an older save envelope cannot authenticate that state. Provider contract storage also must not silently use a pre-provider envelope.

Activate schema 29 for native supplied freight and schema 30 for supplied freight with Alien companion storage. Retain schemas 2 through 27 and leave standalone provider schema 28 unsupported. Provider state can coexist with actual freight in 29 or 30 only after validating its real owner, instance, payload and any native care claims. The presence of provider state alone does not select a freight schema.

Inspect reserved fields at native schema paths before decoding. Reject explicit nulls, malformed bounded collections, misplaced custody and native state in the scrubbed Commander header. Authored script data and payload keys with the same names remain ordinary authored values. An allowed provider optional must be a nonnull bounded valid provider object; decodeIfPresent must not erase an explicit null.

Keep chunk hashes, UUID generation names, typed ScriptValue codec, size limits, symlink refusal, semantic limits and atomic pointer publication intact. Alien pages remain codec 1; its existing schema-27 header policy applies only to envelopes containing the Alien companion. Game-over freight must retain either pending destruction evidence or a terminal disposition. Failed loads must preserve the live game and disk.

Validation must use genuine native freight acceptance for custody and actual fatal transition for pending loss. Additional provider and empty Alien values test storage composition only, with fresh identities bound to the same real freight owner; they prove no provider admission, readiness, crew care, acquisition or fitting. Existing partial/final freight transaction tests remain separate and unchanged. The final composed build, focused tests and full `make ci` gates remain required.
