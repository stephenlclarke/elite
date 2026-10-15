# feat(gallery): navigate campaign assignments and review their root trials

Campaign Gallery details gain actual assignment statuses/objectives and navigation to exact saved children and their immediate owners. An owned child's Try campaign action reviews its exact root campaign, with Back selected initially, before starting an isolated trial. Read-only declarations and missing content never create missions or erase saved property.

Implementation is based on engine commit `81814a69f26deb7ef8f5d4b4534b1537feac4e79`; its earlier validation is prerequisite evidence, not validation of this change. The assigned files are MissionGallery.swift, ScriptGalleryTrial.swift, ScriptCampaignGallery.swift and focused Gallery tests/docs. Researcher-owned campaign/schema/persistence/finance code remains outside this slice. The Orchestrator approved only the Gallery pointer forwarding, page identity/type-scoped dispatch and last-painted AppKit key/pointer/menu integration, plus one existing test paint call. Renderer, input pumping and other engine owners retain their broader files.

Validation in progress: checkpoint `8036f5c` passed 18 focused and existing-regression tests, including four outcome cases, native physical patrol/combat/docking/report/debrief from the owned-child Gallery action, isolated Save/Load/Return with unchanged live save bytes, foreign-receipt rejection, and compact/wide frame bounds. Strict Swift formatting, Markdown lint and diff checks pass. Painted-Gallery input source is implemented; its compile/regression runs, native image inspection, full CI and the required review cycle remain pending the coordinated validation lease. This draft must be updated with final immutable evidence before delivery.

Compatibility: existing saved campaign bindings and save format19 are retained; all new navigation/review state is transient. No finance services or historical mission activation are added. Existing noncampaign trials and retry rules retain their acceptance checks.

Request: [ISSUE-mission-campaign-gallery.md](ISSUE-mission-campaign-gallery.md).
