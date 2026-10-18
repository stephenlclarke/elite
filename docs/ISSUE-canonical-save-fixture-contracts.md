# Correct current save and legacy migration fixture contracts

## Recorded failures

Full CI 331 failed at `14899e22a04789fe280f69e54987be80b8c06011`. Seven mission methods and four general methods used stale fixture assumptions: a baseline before canonical save or actor preparation, current owned equipment passed to the legacy raw loader, modern header fields inside synthetic old save envelopes, schema 21 instead of the current ordinary schema 26, a positional Gallery selector, or an assumption that no external packs means no built-in trial. The raw log is `/tmp/elite-full-review-ci-331/ci-331.log`, SHA256 `15dd08a591bb90b4bc93c37410cba57b2227443f45f09ab727ab1b7fe6abaf03`.

## Required behavior

Current Commander saves must exercise the actual versioned writer and loader. Genuine unprepared legacy Commanders must continue exercising raw migration, including finite Clarke cash and explicit laser mounts. Old schemas must reject modern hardware and mining fields, and an otherwise compatible old header must also reject actual newer pledge evidence with correct chunk hashes.

Isolation comparisons must follow the initial canonical save while separately conserving original cash, cargo, name, hull, equipment and mission property. Standard stock drive preparation must preserve the actual owned device, component and provenance through flight, exchange and save/load. A second owner loaded into the same runtime must reset the prior owner's target cycle even at the same visit tuple. Accepted fresh loading must discard actual old dead mission bodies without crediting their deaths to the new Commander.

Gallery assertions must select the actual service owner by saved instance identity. The real built-in native people entry must advertise its available trial, while its private trial Gallery must advertise neither another trial nor retry and must preserve the entire live parent.

## Scope

Change exactly eleven existing methods in eleven test files, with three local fixture helpers and this issue/PR pair. Retire the superseded single-use scene-isolation helper. There are twelve expanded test cases because the campaign method has two parameter values; the courier fatal/ordinary cases and eighteen legacy schema versions remain internal loops. Production code, loader/header guards, simulation behavior and unrelated test methods remain unchanged. See the [PR handoff](PR-canonical-save-fixture-contracts.md).

Source checks alone do not establish runtime correctness. G1 owns the separate CI 331 crash and the authorized combined native validation after Root reviews this leaf.
