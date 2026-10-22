# Issue #98: native contact lookup stack fault

## Problem

PR #84 head `239583aa` compiled in automatic run `39774626467`, then actual runtime Tab contact selection crashed with signal 10 / bus error. The symbolic stack identifies `___chkstk_darwin`, `ScriptInstance.definition.read`, retained mission actor pack lookup, current native binding and G11 contact selection. The XML is truncated; zero methods qualify. This is separate from fixture issues #96/#97 and does not close #85.

## Correction

Replace only the private one-element-array COW backing of `ScriptInstance` with private reference COW storage. Direct stored-field readers avoid the whole array-element projection. Every mutation must establish unique ownership before yielding. Clone from a backing reference, retain the existing private value and flat Codable object, and preserve shared-storage equality plus full value equality for distinct storage. All native pack, actor, ownership, geometry and current binding checks remain.

## Acceptance

A focused regression must prove copy/snapshot isolation, nested mutation, independently decoded value equality and unchanged flat JSON. Keep actual Tab review/arm and writer-refusal regressions. Compose only actual delivered C01, preserve every selected method and qualify the final head through independent review and its existing automatic workflow. No local Swift execution or new diagnostic campaign is authorized.
