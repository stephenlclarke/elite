# Remove mandatory bot review from CI and delivery

The latest user instruction removes automated bot-review requests from CI. The existing workflows and tooling contain no such calls; the requirement is instead in the active agent guidance and two current README review descriptions. Those instructions could keep triggering requests and waits outside the workflow files.

Remove that requirement while preserving independent actual-code/result review, disposition of existing actionable findings, required final-head checks and approvals, and ordinary protected merges. Historical request/error receipts remain dated evidence.
