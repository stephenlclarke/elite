# Swift 6.1.2 cannot type-check two contract-board fallback chains

Required CI 39524048224 for published df62ccd4 fails during mission-packs-check prerequisite compilation, before native units. Actual synthetic merge420512154e26b9dcf18a2854330bd92144cf8d61 reports two unique expressions: ContractBoard.swift:23 ContractBoardRow.key and ContractBoardDisplay.swift:125 local detailReason. Both exceed the compiler's reasonable type-checking time. Raw log SHA256 is0bb81f32f6ac76053122e781a8fca64196953661270a4d0188673cdc0a36740c; retained disposition is /tmp/elite-coherent-pr-checkpoint-df62ccd4/compile-failure-disposition.json.

Break only these long optional fallback expressions into independently typed sequential checks. Each chain must retain its own precedence, returning the first non-nil value even when it is an empty string. Do not combine the chains: the row places people before finance and RRS, while the displayed reason places RRS before finance and people. Preserve lazy fallback evaluation and the exact unavailable/selected-reason fallbacks. No gameplay policy change is needed. Local Swift6.4 compilation alone cannot establish hosted Swift6.1.2 repair.

See [the correction and selected qualification](PR-contract-board-compiler.md).
