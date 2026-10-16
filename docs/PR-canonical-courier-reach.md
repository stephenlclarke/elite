# Use canonical native reach for new courier plans

Recovered navigation upgrades can change actual jump reach and fuel efficiency.
New courier plans freeze those native values in reach revision v2, and acceptance
uses current native first-leg and full-tank range. Old v1 plans keep their exact
validation and replay rules, including all original draws and destinations.

Regression source covers real purchases and recovered upgrades, first and later
legs, refusal after an actual stock navigation refit, legacy board persistence
after a purchase, and malformed version fields.

Validation is **source-only, uncompiled and unexecuted**: strict formatting and
whitespace checks passed. Integration with the canonical provider, focused tests,
full `make ci`, and the required clean GitHub review remain outstanding. The
central integrator owns publishing and merging.
