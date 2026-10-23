# Compose reservation audit with corrected development

PR100's authored source at f582b63a was absent from the af706a13 candidate.
That candidate remains unchanged and excludes ReservationAudit and Sorel.
This composition brings only the already-authored PR100 packet into current
development; defensive training PR87 remains separate.

Three conflicts require resolution. Keep the current borrowed Meridian
prefix/body/absence helpers and add the original audit shape check to the body.
Keep the exact effective selector union and its matching count fixture. Preserve
current COW storage, complete equality, flat codecs and lifetime repairs.

The union contains472 methods: all462 current methods plus10 audit methods.
This is an inventory, not a full execution result. The bounded affected packet
contains four existing audit methods and16 authored cases, mapped to issues
101,102 and104. No original assertion is removed.
