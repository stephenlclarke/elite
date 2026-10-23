# Compose authored training with qualified reservation source

PR87's already-authored source10849b7c is absent from the af706a13 candidate.
Compose it with canonical16b1c5f7, which includes qualified PR100. Preserve the
three training fields through current COW storage, complete equality and flat
codecs; retain borrowed runtime validation and authored physical observations.

Five actual conflicts cover availability, mission storage/policy, persistence
and selector/count files. The old reservation137/138 envelope remains strict
and highest. Validate optional training under its existing closed135/136 local
namespace, then pass the original reservation schema to audit-first preflight.
Older training schemas must still reject reservation claims.

Add a bounded closed-archive test for normal/alien reservation-only,
training-only and mixed records, version precedence, roundtrip state, refused
older/unknown/embedded fields and training-field COW/equality. It uses existing
valid component fixtures and does not simulate a mixed native journey. Retain
the original93 physical observation method in the minimal affected batch.
