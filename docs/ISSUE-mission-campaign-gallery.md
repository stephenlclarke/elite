# Campaign Gallery entries cannot navigate their owned assignments

The scoped-campaign engine retains exact parent/child bindings and isolated root trials, but Gallery entries expose relationships only as briefing text. Players cannot open a campaign's actual child or return to its immediate owner. Trying an owned child must review its root campaign's trial instead of accepting or restarting that child independently.

Implement native relationship projections and navigation on engine base `81814a69f26deb7ef8f5d4b4534b1537feac4e79`. Show actual child objectives, outcomes and suspension reasons; preserve unstarted and missing-content previews without mutating campaign state. Keep immediate-owner and root identities distinct, Back/scroll context intact, and trial resources, calendar, saves and input epochs isolated.

Validate two campaigns sharing a child template, nested ownership, missing/unstarted/suspended/terminal cases, fresh deliberate root-trial review, native physical patrol/report/debrief, save/load/Return, foreign receipt rejection and compact/wide renderer evidence. Existing mission confirmation and noncampaign Gallery behaviour must remain intact. Finance and historical campaign activation are outside this change.

Implementation: [PR-mission-campaign-gallery.md](PR-mission-campaign-gallery.md).
