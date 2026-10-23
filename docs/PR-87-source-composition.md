# merge: compose training with current reservation codecs and value storage

Compose original PR87 head10849b7c with current16b1c5f7. Retain full training
semantics and original assertions while adapting its three fields to bounded
Field storage, clone/default/codec helpers and logical equality. Storage
inventories become54 ScriptInstanceValue fields,26 engine fields and60 Commander
fields. No earlier stored member or selector is removed.

Reservation137/138 keeps write precedence. The archive wrapper checks training
with the existing closed local namespace and sends the original reservation
schema through strict audit-first lowering. Extract only the existing native
mission envelope choice, used by the real writer, for direct precedence checks.
The current availability and borrowed validator helpers remain intact.

Exact selector union:472 current methods plus385 incoming methods with335
shared gives522; one new codec method gives523. This is an inventory. The
minimal affected batch is the original93 observation method and the new
normal/alien archive method, including training-field COW checks.

Strict scoped Swift formatting, whitespace, six Python report fixtures and25
equality fixtures pass. Independent actual composition/codec/unit review and
focused Swift execution are pending. No523-method, native journey, full quality
gate or release pass is claimed. The existing af706a13 candidate is unchanged.

The new mixed-codec method's two cases pass at33a57dca; retain that unchanged
boundary's result. The original93 method failed only during setup: its second
flight had not adopted the original provider frame. Add that one assignment
before preparation and rerun only the affected93 method. No production policy,
view-loop assertion, codec code or new-codec fixture changes in this correction.
