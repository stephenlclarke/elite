# docs(workflow): sync tap status and standing merge approval

The README and Homebrew guide now identify the actual published Elite 1.5.1 tap update and its merged PR10. The L337 1.6.0 repository cask and direct download stay separate from the tap, which currently contains only elite.rb. Both casks and the historical portable release receipt are unchanged.

AGENTS.md now records Stephen's standing approval to use the owner override without another question when all final-head required checks and the MBA's independent review pass and another account's GitHub approval is the only blocker. Branch protections stay unchanged. Existing independent review, finding correction and required-check rules remain in force.

Actual metadata main 0bbc passed both full 3,445-method normal runs separately, zero-leak lifecycle validation and exact-main Sonar. All 19 eligible main checks passed; the source-only isolated workflow correctly did not run for that metadata push. Independent review 944af8a1 cleared those results. This successor is a separate metadata candidate and does not inherit that head's quality qualification.

The six-path candidate preserves the full outside tree and ledger prefix. Focused Markdown formatting is recorded separately; no Ruby, runtime, release or download retest is needed for unchanged casks and code. Current-head required checks and the normal independent review/merge process still apply. [Problem and scope](ISSUE-tap-status-standing-approval.md).
