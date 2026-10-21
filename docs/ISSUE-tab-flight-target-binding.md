# Use Tab alone for flight target selection

FR-008 requests removing R as the flight-targeting key, using Tab instead and updating all documentation. Core targeting and work targeting already share cycleAutoTarget; R and Tab were aliases at three input boundaries. R therefore also cleared native steering and actor controls as a targeting side effect.

Remove only the flight R alias. Preserve the established target order, fitted tier/module checks, ship tracking, station automatic docking and work guidance. Preserve R text input, mission retry, cabin refit and showroom reset, plus Tab focus/navigation in other screens. See [implementation](PR-tab-flight-target-binding.md) and the [persistent request log](FEATURE-REQUEST-LOG.md).
