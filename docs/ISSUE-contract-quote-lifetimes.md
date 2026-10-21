# Board refresh retains future publication and quote snapshots

Full 202 on `1c187ac2f70bfd634cf7913d19b5867f07bf5bb3` failed with 11 assertion headers across three methods and signal 10. Its exact binary is the separately focused-passing 200 artifact, `7821e287c5e47514000e583045b2da8310ba4713baf4bdfffca4707e04c46ebf`. No full passing summary or sanitizer/leak acceptance exists.

No-rebuild debugger 203 separately stopped in `typedUnaffordableFoodPledgeRefreshesTrialBoardWithoutChangingProperty`: the real error-refresh route opens the board, simulates funded quote acceptance and constructs its committed pledge event context before Foundation's sequence stack probe stops. Its actual thread is `/tmp/elite-debug-crash-203/actual-stopped-thread.json`; no matching original OS report proves equivalence to the unobserved 202 signal.

The linked binary reserves two Game-sized buffers in `openContractBoard`, including the later publication copy, and a Game-sized simulation plus Commander-sized later resource snapshot in `contractAcceptanceQuote`. Keep every simulation, refusal, confirmation and rollback check, but scope publication and quote construction after the nested acceptance work. See [the repair](PR-contract-quote-lifetimes.md).
