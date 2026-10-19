# Use canonical native reach for new courier plans

Recovered navigation upgrades can change actual jump reach and fuel efficiency.
New courier plans freeze those native values in reach revision v2, and acceptance
uses current native first-leg and full-tank range. Old v1 plans keep their exact
validation and replay rules, including all original draws and destinations.

Regression source covers real purchases and recovered upgrades, first and later
legs, refusal after an actual stock navigation refit, independently pinned v1
board and accepted package persistence through canonical load and refitting,
and malformed version fields.
Admitted grandfathered Military navigation with zero fuel cost keeps its native
full-cap reach even with an empty tank; the regression checks actual native load
admission without inventing a progression receipt.

Validation is **source-only, uncompiled and unexecuted**: strict formatting and
whitespace checks passed. Integration with the canonical provider, focused tests,
full `make ci`, and the required clean GitHub review remain outstanding. The
central integrator owns publishing and merging.

## Current original-world provenance boundary

The later installed original-world catalogue replaces BBC names and coordinates without aliases. The unchanged historical `courier-native-reach-v1.json` remains pinned provenance, but its BBC route proof is now required to refuse current-world publication. This retires its obsolete cross-universe load/refit expectation; the production v1 reach parser and typed-field validation remain unchanged. Current original-world success and deadline cases are explicitly frozen in [the witness packet](PR-current-world-courier-witnesses.md), with all actual native travel, custody and once-only settlement assertions retained. These authored changes await central execution and do not reinterpret earlier pass records as current acceptance.
