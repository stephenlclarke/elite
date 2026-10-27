# docs: clarify current development startup and equipment prerequisites

## Result and motivation

The README now distinguishes published 1.4.0 Jameson/Right-On Commander behavior from current development L337/Rowan Calder/Avenor/SH025/720 CR defaults. Source inspection confirms that current XYZZY preserves the commander name, refits Cobra Mk III and grants its initial cash once. The directly contradictory controls paragraphs use the same distinction.

First-flight guidance explains manual docking without a computer, the paid Basic → Advanced → Docking chain before Tab station AUTO, and the two fitted working Passenger Berths required for passenger journeys, base 1,000 CR each before discounts. Historical reference/legal text, release URLs and renderer media remain unchanged.

## Validation and compatibility

Scoped Markdown lint, Git whitespace checks, local file-link target checks and comparison of README media/external URLs against the parent commit pass. This is documentation only: no game build, test, UI run, generated media, equipment grant or release publication. It does not close M01, passenger-flight acceptance, coverage, sanitizer/leak gates or full CI. No remote issue or PR is created. Companion: [ISSUE-current-development-startup-docs.md](ISSUE-current-development-startup-docs.md).
