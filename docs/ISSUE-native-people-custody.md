# Native occupied pods and captured crew need original-person custody

## Motivation and required behaviour

FR-005/006 require actual captured crew and tracked single-unit occupied-pod rescue, preserving every original person. Aggregate Slaves stock and automatic timers cannot prove which people left a source craft or prevent their reappearance. FR-017/018 additionally permit capture during the disabled window while other original crew eject at saved random times; an array-index ordinal model would duplicate or renumber people when those events interleave.

## Scope and compatibility

Implement explicit source/ordinal custody, bounded actual-disable episodes and discharge evidence, physical tracked scoop and cutter contact, real hold limits, native care/sale/history reviews and synchronous full save publication. Preserve ordinary protected occupants, charter accommodation, current actor ownership and existing station/Gallery proof paths. Escape abandonment and death have distinct original-person dispositions. Version 24 must be explicit without weakening original 21/22/23 guards or inventing historical ejection times.

Actual electrical phases, same-ship recovery and traffic return remain G1's central integration responsibility. Full medical treatment, hiring, generic rescue providers and historical campaign adaptation remain open. See the [source candidate and validation limits](PR-native-people-custody.md) and [custody contract](NATIVE-PEOPLE-CUSTODY.md).

Composed compile check 249 exposed seven mutating Game calls inside Testing macros before test execution. Each actual call is now evaluated once into a local, retaining its original required/negative assertion. This is a fixture compilation correction, not runtime acceptance or a change to custody rules.

Check 250 then exposed one exclusive-access overlap while a legacy fixture assigned an EMP field and read the same Commander in its right-hand expression. Staging the unchanged physical-time calculation in a local preserves the original scenario and assertion. No tests executed in 250.

Check 251 exposed the same exclusive-access pattern in the separate legacy save roundtrip fixture. Its time read is likewise staged before mutation; the actual save/load and downgrade checks remain intact. A source search covered the remaining new people fixtures for this pattern. No tests executed in 251.
