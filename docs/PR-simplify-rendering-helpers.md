# refactor: simplify rendering and equipment helpers

Resolve the 18 Sonar maintainability findings from the flight-assistance update. Replace nested conditional expressions with named decisions, flatten equipment catalogue lookup, combine status-scroll conditions and group clipping/gauge geometry arguments into existing range/rectangle types.

Gameplay and rendering behaviour are unchanged. Existing regressions cover chart ordering, all gallery states, cockpit bounds, line clipping, complete ship silhouettes, equipment selection and native rendering. Regenerated README media must remain byte-identical. Validation: `make ci` passed with 139 tests, 94.86% overall Swift coverage, clean Thread Sanitizer and Address Sanitizer runs, and 0 leaked bytes. Strict Swift formatting and Markdown lint passed. `make readme-media` produced byte-identical tracked artwork. Sonar verification follows merge because analysis is restricted to committed main.

Request: [ISSUE-simplify-rendering-helpers.md](ISSUE-simplify-rendering-helpers.md).
