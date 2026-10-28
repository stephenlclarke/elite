# Avoid temporary vertex arrays in shaded icon projection

## Change

The shaded renderer now passes face indices and the existing transformed vertex array to a small indexed projection overload. When every face vertex is in front of or on the near plane, it creates only the required screen-point output. It avoids the caller's temporary camera-space array and the clipper's second camera-space array. Other cases call the unchanged original clipping implementation.

The renderer records visible faces only after the shaded branch has continued. Wire drawing still records the same faces and uses the same detail filter. The face sort, culling predicate, texture path, projection formula, panel colours and output order remain unchanged. No cache, autorelease workaround, model reduction or actor change is introduced. [Observed problem and limits](ISSUE-m01-icon-projection-memory.md).

## Regression assertions

One existing `PanelClippingTests` method now calls a private parity helper. It compares the indexed output exactly with the original mapped-vertex projection across empty and short faces, wholly visible faces, the exact near plane, crossings, wholly hidden faces and nonfinite coordinates. Forward and reverse noncontiguous indices check vertex order. Three projection configurations include the actual icon camera. The helper adds 72 comparisons without adding a test method or changing a selector. All previous assertions in the file remain intact.

The two original icon tests and the exporter remain byte-identical to the failed source. The approved mesh, materials, all output sizes and filenames, image assertions, sanitizer settings, 2 GiB guard, diagnostics, internal concurrency and required atomic cohorts remain unchanged. The existing 3,403-method inventory is expected to remain the same; fresh actual discovery must confirm it.

## Validation performed

Four source/numeric checks pass. An independent numeric model made 3,132 exact ordered comparisons across finite, boundary, crossing and nonfinite inputs. It also detected three deliberate wrong-index/order/length changes. These model checks are not Swift unit execution or memory measurements.

Source checks confirm that the original clipping function is byte-identical, the renderer has only the proposed call and visibility-recording changes, all original panel assertions and test IDs remain intact, and the icon tests/exporter are unchanged. Scoped Markdown lint and diff whitespace checks accompany the frozen packet. No compiler, native test, render, profiler, resource/process probe, worker/cache/policy/session change, API, publication or release ran.

## Required handoff

The extended Swift assertions are **UNRUN**. This packet remains in development/validation pending, rather than ready for integration. Root must route independent source review and coordinate G1's existing native lease for a matching compile and focused actual `PanelClippingTests` plus both original icon tests. The source owner must close any findings and confirm those tests pass before integration handoff.

The change removes definite allocation work on the observed active renderer path. The saved failure data cannot prove it caused the entire RSS excess, and this packet does not claim measured savings or fit. G1 must prepare the new committed source identity under reviewed policies and qualify it with the unchanged guard and complete required cohorts. Preserve the old failed source, raw failure evidence and used counter. Fresh full ASAN/TSAN, normal coverage, leaks, actual CI/main analysis and release gates remain required.
