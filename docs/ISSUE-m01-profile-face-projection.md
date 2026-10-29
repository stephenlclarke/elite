# Profile construction creates a temporary vertex array for every face

## Source finding

`SalvageCatalogue.makeProfile` maps each valid face's indices into a temporary `[Vector3]`. It uses that array only to calculate the first-three cross product, ordered midpoint and radius inputs. The array never escapes into the retained Face metadata or profile. The immutable mesh already contains every value required by those calculations.

The resolved source projection for 132 eligible disabled-profile candidates has 143,707 count/index-valid faces and 484,633 projected vertex references. Three eight-byte Double fields total 11,631,192 bytes of cumulative scalar copy payload. These are source evaluation counts, not observed factory calls, compiler materialization, simultaneous live storage, native allocation or RSS savings. Actual factory validation can still return nil.

## Observation limits

The latest diagnostic on `2d82f092c2700d5b028982942864002ffe917eac` again emitted 60 records ending at SH061 emp-before. There was no emp-after or body-exit. The censored interval includes observer return, lookup, `#require` and following sampling. It does not prove factory entry, cold cache, changed-branch execution, appended-helper reach or allocation cause. Different overshoots do not measure savings or sufficient fit.

## Selected correction

Read the first three vertices directly and reduce the original indices in their existing order. Keep the full count/all-index guard, strict cross-length cutoff, normal formula, count reciprocal, ordered Double radius array and its exact Array.max call. Leave bounds maps, whole-mesh radius, retained Face array, section filters, facing fallback, comparator, ties, cache and SH061 paths unchanged.

Indexed gathers, bounds checks and code generation can cost more than reading the contiguous scratch array. Added old-array test oracles also cost allocation and time. This source reduction does not claim universal speed, measured RSS benefit or a cause-specific fix for the refusal. See [the implementation and validation handoff](PR-m01-profile-face-projection.md).
