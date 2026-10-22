# Issue #98: native contact lookup stack fault

## Problem

PR #84 head `239583aa` compiled in automatic run `39774626467`, then actual runtime Tab contact selection crashed with signal 10 / bus error. The symbolic stack identifies `___chkstk_darwin`, `ScriptInstance.definition.read`, retained mission actor pack lookup, current native binding and G11 contact selection. The XML is truncated; zero methods qualify. This is separate from fixture issues #96/#97 and does not close #85.

## Correction

Replace only the private one-element-array COW backing of `ScriptInstance` with private reference COW storage. Direct stored-field readers avoid the whole array-element projection. Every mutation must establish unique ownership before yielding. Clone from a backing reference, retain the existing private value and flat Codable object, and preserve shared-storage equality plus full value equality for distinct storage. All native pack, actor, ownership, geometry and current binding checks remain.

## Acceptance

A focused regression must prove copy/snapshot isolation, nested mutation, independently decoded value equality and unchanged flat JSON. Keep actual Tab review/arm and writer-refusal regressions. Compose only actual delivered C01, preserve every selected method and qualify the final head through independent review and its existing automatic workflow. No local Swift execution or new diagnostic campaign is authorized.

## Actual follow-up evidence

Head `e399275a` compiled in 803.25 seconds in automatic run `39778352147`, then crashed with signal 10 / bus error at `ScriptInstance.id.read` on the same actual runtime Tab path. No method completed PASS, and XML is truncated. The reference box still stored one aggregate `value`; `yield storage.value.id` still projected that aggregate. The follow-up removes this intermediate aggregate entirely: the private COW class directly owns the same 53 declared fields and defaults. Its reference-copy initializer and bounded value-equality groups explicitly cover all 53 fields in original order. All 49 unique-before-yield accessors, public value semantics, exact Codable keys and real native input remain. This source correction remains unproven until actual execution.

## Confirmed retained fit-match boundary

The direct-field head `0e80f8ae` compiled in 685.13 seconds in automatic run `39782182054`, then crashed with signal 10 / bus error at the `missionActorFitMatches` call in `retainedMissionActorDescriptor` (`ScriptNativeBridge.swift:58`). The symbolic stack continues through the same native binding, G11 contact filter and real runtime Tab path. It no longer reports a `ScriptInstance` getter. The XML is truncated and qualifies zero methods. Retain the completed direct-field storage audit and change no storage/schema further.

The bounded follow-up borrows read-only inputs and marks the retained lookup, fit match and directly called C01 declaration/profile/design helpers non-inline. Function bodies, predicate order, duplicate-body checks, admitted encounter/tag/location joins and full NPC fit/component/model/geometry equality remain identical. Actual delivered route base `b46115aa` composes once, adding four inherited methods for an exact 362-method union. No cache, authority bypass, new probe or diagnostic job is introduced.

## Compile-only prerequisite

Head `c8728210` did not reach runtime: run `39785814462` failed production compilation because the new borrowed body/retained parameters were consumed by existing short-circuit/component closures. Issue #103 tracks that distinct compiler criterion. Ordered direct optional guards and a small borrowed component helper preserve the original predicate order and comparisons. Runtime #98 remains open; neither compilation nor a clean source review proves its actual native Tab path.

## Confirmed caller lifetime follow-up

Run `39787112105` at `63ded61c` compiled the production/test target in 917.40 seconds, proving and closing #103. Its completed inner job `119853139566` then reported signal 10 at the retained fit-match call (`ScriptNativeBridge.swift:62`) through the same G11 Tab path, with zero completed PASS methods. The parent workflow still appeared active after the inner job failed; use the completed inner job result. #85/#96/#97/#98 remain open.

The G11 role reader held its full source, physical, fit and retained-actor snapshots across that independent native binding query. The approved lifetime correction places the identical ordered pre-binding guards in a private non-inline helper. It returns only role, child UUID, retained actor UUID and native actor identity. Its frame completes before the same fresh native binding query and same three identity comparisons. No ownership predicate, fit/component/model check, query authority, storage, schema, actor or selector changes. An explicitly leased existing-cache Core preflight is permitted for this coherent correction; actual runtime qualification remains required.

The approved existing-cache Core preflight passed in 16.10 seconds with exit 0, and its CPU lease was released. No local unit/native runtime executed. The ordered prefix/suffix and selector proofs, independent review and actual hosted runtime result remain the acceptance evidence needed for this frame correction.
