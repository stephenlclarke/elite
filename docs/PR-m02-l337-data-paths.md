# Default L337 application data to its own directory

The three default locations now share ~/.xyzzy/l337/: commander.json, mission-packs and script-packs. Each production change is one path literal. No format/schema, storage representation, remembered explicit destination, install validation, actor/lifetime behavior or bundle lookup changes. No predecessor directory is searched or migrated.

This fix branch is stacked on qualified c31417ba in [PR #215](https://github.com/stephenlclarke/elite/pull/215). That parent head, its reviewed naming/help code and its 529-pass qualification remain intact. The packet does not import or rehead M01. Relevant controls/mission-authoring guides and current-development README paragraphs name the new paths; published 1.4.0 uninstall/update paths remain unchanged, and its legacy TOML library is distinguished explicitly.

Two ApplicationDataPathUnitTests methods check the actual default CommanderSaveSession and both library directory consumers, plus the existing explicit-save and failed-restore fresh-destination policy. They use nil preferences and constructed URLs, with no home-directory writes, app launch, save/load or migration execution. The selector retains all 529 parent methods and appends only these two names for 531 total. No workflow or other owner's registration changes.

Local validation uses strict Swift formatting, Markdown/whitespace checks and the affected Python selector/report fixtures. Swift execution and independent source/result review remain pending until the actual new-head hosted run and MBA review, M01 first. No local compiler/native/performance job, signed packaging or usable delivery is claimed. Existing M01 merge hold remains explicit; source/unit acceptance and release remain separate.
