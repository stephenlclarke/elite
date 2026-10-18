# Shared flight controls and live weapon status

The generated flight control definitions describe W to change weapon, held Return to fire, E for ECM and Q to release hold. Native consumers still cycled absent fittings, selected the work tool late, and displayed a generic tool line without live readiness. An interrupted Return could continue a charge or operation, particularly when a native command rolled back after a refused save.

## Required behavior

- Consume generated bindings in native input, menus and actual runtime help pages, preserving each menu's own Return/W meanings and Tab/F/I flight behavior.
- Keep the player control guide consistent with the shared bindings: Return operates the selected tool, W cycles fitted tool types, and the retired A fire alias is not documented as active.
- Select the mining laser or cutter once when acquiring its supported hold. Preserve a manual W override, cycle fitted tools, and never substitute a combat shot for an unavailable work tool.
- Require fresh Return after selection, approach-to-hold readiness or interruption. Releasing Return stops the operation and retains guidance; Q releases guidance with world momentum and pending native custody intact.
- Reserve a WEAPON row above the scanner in every flight view and display style, including without a selected target. Derive activity from actual selected emissions and charge state, and readiness from resources and real native work contacts.

## Boundaries

This leaf changes transient input and presentation. Native extraction permissions, transactional publication, cargo custody, physics mass accounting and save formats retain their existing authority. The full capital-hull hold eligibility and manual-target fallback refinement is a separate bounded follow-up. No prior passing gameplay journey qualifies this new leaf.
