# Bound mission applicability pack ownership

## Motivation and evidence

[Issue169](https://github.com/stephenlclarke/elite/issues/169) tracks the current exact-image applicability boundary in the M01 packet. The previous `feab1bcb` normal six-method batch built in285.35seconds, then exited1/rawSIGBUS10 after297.460538459seconds with zero completed methods/assertions and unfinished52-byte Swift Testing XML. Its changed ABB738A8-4275-3ECC-8436-E96F1E89A6E5 image has no matching normal report among27 saved reports.

One bounded diagnostic reused that exact built image, with the same original four methods plus existing two recorder-boundary methods, `--skip-build`, default stack/environment and jobs3. At published `75eec9bf` (game/test bytes equal `feab1bcb`), PID43019/start22:59:11UTC stopped at static `scriptInductionSeedApplies` entry, ScriptDirector.swift226, through `scriptUnavailable`, contract acceptance quote refresh and the original board-browsing method. Logged slide0x11f000000 and UUID match the retained guest binary; SHA256264897d8565edbfc3b1252835062c07d47063855afa11d1639fcf8ae5571142b is verified before/after by the capture collector. Offline symbolization is retained in `/tmp/elite-m01-marker-owned-capture/offline-atos-mba.txt`.

The diagnostic took14.079190333seconds, exited driver1/debugger0, detached and left no owned process. There is no saved guard map, chkstk or Game-copy top. This identifies the current source boundary, not the exact failing buffer, earlier normal crash cause or proof that issue164 passed. It is not test qualification.

## Implementation

Borrow ScriptPack across the eleven existing private noninline applicability predicates in the same ordered `scriptUnavailable` dispatch. Each previously owned the full pack to read identity, optional feature or capability fields. Express each original A-or-B predicate as an explicit first-condition return followed by the second condition. This preserves short-circuit order and avoids capturing a borrowed pack in the second-condition autoclosure under Swift6.1. Keep all dispatch calls and full matched-family Unavailable validators, requirements and errors unchanged.

## Validation

Strict Swift formatting and diff hygiene pass. Independent actual-source review and one combined normal execution of the same six affected methods are pending. No implementation-mirroring test, selector removal, hash shortcut, extra capture or runtime-default workaround is introduced.

## Compatibility and remaining limits

No Game/Commander state, actor isolation, pack identity/hash, save/schema, UI, mission behaviour, dispatch order or quality threshold changes. Source ownership reduction is not proof of compiled stack savings or runtime success. Required final-head quality, coverage, sanitizer/leak gates and original-method completion remain unqualified.
