# Fuel gauges divide by capacity without an invalid-input boundary

The modern cockpit and legacy dashboard directly divide fuel by fuel capacity. A future explicitly authorized zero-capacity hull would therefore feed a nonfinite fraction into gauge clamping. Nonfinite numeric inputs should also display an empty gauge without reaching the rendering arithmetic.

This presentation fix does not authorize any zero-capability hull or change fitting, fuel storage, refuelling, FULL labels or gameplay. The existing pure static resource-level helper already supplies the required finite-input/positive-capacity guard and visual clamp without a Game instance.
