# Serialize native file intents with the commands they follow

Typed native file intents now enter the same FIFO batch as keys, shop purchases and recovered-equipment actions. A single-consumer guard prevents a reentrant batch from overtaking one already awaiting the runtime. `GameRuntime` remains the only mutable simulation owner; its typed save/load operation delegates to the existing non-suspending validation/write/publication path.

Save and Reload resolve the active URL in processing order, including an earlier successful Open. Save As and Open retain panel-selected URLs. The active URL and last-successful-save preference change only after success; opening alone still does not claim a new successful save. Successful loading resets held controls and publishes a fresh snapshot with the existing invalidated inventory context. Menu Open/Load no longer launch independent loading tasks.

Three native regression methods exercise Save(A), Open(B), Save-active before one drain; explicit Save As followed by Open; and failed save/load rollback of the full Commander, bodies, epoch, active paths and original bytes. Existing native keyboard Save coverage still requires an earlier queued Cobra restore to be saved. Failure presentation is injected at the narrow main-actor boundary so deterministic failure tests do not open modal alerts.

This slice is source-only and unexecuted. Strict formatting, syntax, Markdown and whitespace checks precede the assigned focused lease. The earlier 026 gate is historical evidence for the previous runtime, not acceptance of this repair. Motivation: [issue handoff](ISSUE-ordered-native-commander-files.md).
