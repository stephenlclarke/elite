# Campaign Gallery relationships

Gallery relationship projections use exact saved instance bindings and pinned child declarations. `selectedCampaignAssignments` exposes each assignment's title, actual outcome/status, objective, suspension/unavailability reason and saved instance, if started. A declaration without a binding is Not started. Terminal outcomes retain their actual label even if content is missing; missing content is explained separately.

On campaign details, Return or the Campaign links action opens the relationship list. Up/Down selects a relationship and Return or a click opens it. Existing assignments open their exact saved row. Unstarted declarations open read-only previews. Child details show Part of the immediate campaign; View campaign opens that immediate owner. Escape restores the prior relationship/reading position. Root identity is resolved separately from immediate ownership.

Try campaign on an owned child opens a root-specific isolated-trial review. Back is initially selected. Repeated trial commands do not start it; choose Try campaign deliberately. The review revalidates the exact source instance, root, pinned content and commander epoch. Missing content, unavailable requirements, parent-only roots and existing trials remain unavailable. The existing standalone `canTrialSelectedMission` eligibility is preserved; owned-child routing is a separate review action.

All projections, previews and navigation are read-only. Trial creation and durable publication remain in GameRuntime. Save/Load/Restart/Return use the existing Gallery namespace and commander isolation. Finance APIs and historical facility support are outside this addition.
