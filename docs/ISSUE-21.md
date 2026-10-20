# Coherent native gameplay integration checkpoint

## Motivation

The existing draft [PR #21](https://github.com/stephenlclarke/elite/pull/21) needs the coherent qualified native missions, rescue, docking, startup, equipment, save and fixture batch plus final-head quality/review evidence. The previous510 hosted failure reported60issues across26methods and then SIGBUS10. All26reported methods now have local focused passing evidence; formal hosted acceptance remains required.

## Acceptance and limits

Fast-forward the existing owned integration branch normally, preserving worker branches. Run its existing GitHub checks once and request @codex review for the updated head. Fix actionable findings and obtain clean final-head review/checks before merging. Preserve actual failures, branch protection, sanitizer/leak gates and main-only exact-commit Sonar policy. Integrated G08 retains33methods53cases; signed limited1052 verifies startup/menus/gallery, without the G08-specific full player journey. Final docking1063 qualifies four methods/five cases and completes the retained27methods30cases covering all26reported510 methods plus one helper consumer. Unqualified G14 and its separate actual reader crash stay isolated; G10 remains queued afterward. M01 functional acceptance and public distribution remain incomplete.

Previous cancelled/failed quality runs and review service errors remain historical unsatisfied gates. Companion: [PR-21.md](PR-21.md).
