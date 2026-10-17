# Persist alien history without an inline Commander ledger

The reviewed alien page codec and validated-state witness are not yet joined to native Commander saves. An inline lifetime history would exceed the existing 4 MiB Commander chunk and collection preflight bounds. A decoder must authenticate the owner, root and pages before accepting Commander.valid; missing history cannot silently become an empty inventory. Frame queries must use an immutable checked witness instead of replaying permanent source and upgrade history.

Add a version-27 native persistence vertical with one small encoded reference, an excluded immutable runtime cache, exactly five hashed pointer chunks and atomic actor publication. Retain ordinary limits and all older-version guards. This task does not authorize a module grant: authentic cutting, scoop collection, PLUGH fitting, effective flight statistics and physical EMP module counts remain separate native integration work.
