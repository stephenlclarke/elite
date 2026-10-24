# Match the Quit menu to the application title

The Quit menu now interpolates NewCommanderDefaults.title, the authority already used by the application window. With the current title, the label becomes Quit L337. The termination selector and Command-Q shortcut are retained.

This packet contains one authorized label change in EliteApp.installMenu and paired notes. It follows the showroom-help source published in [PR #215](https://github.com/stephenlclarke/elite/pull/215), with a separate commit boundary. It adds no isolated-unit methods and leaves the 527-method selector unchanged. No broad rename or identity migration is included.

Validation is limited to strict Swift formatting, whitespace checks, Markdown lint and inspection of the existing title authority and adjacent menu action. No local compiler, native application or integration run is permitted while M01 holds the CPU. This reversible label change does not warrant an implementation-mirroring test. Independent review, applicable final-head checks and usable application evidence remain pending. This is not M02 completion.
