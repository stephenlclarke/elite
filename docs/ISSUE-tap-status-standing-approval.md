# Synchronize the merged tap update and standing merge approval

The README and Homebrew guide still say the published tap installs Elite 1.4.0 and PR10 awaits approval. PR10 merged on 31 October 2026 at 08:41:47 UTC, and the actual published tap cask now specifies Elite 1.5.1. The tap still has no L337 cask; the separate L337 1.6.0 direct download is unchanged.

After that merge, Stephen explicitly gave standing approval: "Do not wait or ask again. Just do it next time. This is standing approval." Root confirmed the boundary: required checks and independent review must pass for the final head; use the owner override without asking only when another account's GitHub approval is the sole blocker. Keep branch protections unchanged. The repository's unconditional no-administrator-override sentence conflicts with this direct human instruction.

Reserve only the two current tap status sentences, the corresponding agent rule, paired notes and an append-only completion-ledger entry. Preserve both casks, historical delivery receipts, game code, tests, CI and media. This is not a new release or L337 tap publication. See [the implementation note](PR-tap-status-standing-approval.md).
