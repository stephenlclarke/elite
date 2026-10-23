# NPC missile test must follow its original actor identity

[Issue154](https://github.com/stephenlclarke/elite/issues/154) records the a0f focused assertion at GameplayOrdnanceRuntimeTests143. After removing the original launcher, the test reads bodies[0] as its missile. Actual native station population means that position can hold a station. The failed condition says nothing about missile ownership or damage.

Resolve the original launcher by its declared body ID and retain its actual physical identity. Assert its finite ammunition is spent and the second launch refuses. Capture the missile by the original owner's attack origin and retain its exact physical identity/body ID. Remove only the original owner; after advancement resolve that exact missile, then retain the original owner, impact, shield/energy, no-kill and unchanged-cash assertions. No positional or last-body substitute is accepted.

Original failed evidence remains at `/tmp/elite-151-prepared-missile-units-result.json` and its raw log. The same batch's mission fault is separate151, and its process/XML were not a passing result. Focused execution and independent actual-diff/result review are pending.
