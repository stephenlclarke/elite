# Preserve the full solar save comparison while ordering its equipment Set

The solar transition regression now checks typed equipment Set, physical inventory and purchase history equality before comparing the complete encoded dictionaries. Only the top-level equipment field receives a sorted representation. The original six world-transition exceptions remain unchanged; no additional fields or arrays are ignored or normalized. Production code and save encoding are unchanged.

The original 024 failure was classified from its actual and expected diagnostic values. System property-list parsing verified equality of all 24 other top-level fields; the original two equipment strings differ only in order. The [source-only classification](SOLAR-SAVE-ORDER-FAILURE-024.json) retains the raw log hash, extracted-value hashes, method and limits. This does not turn the failed 024 full gate into a pass.

Strict Swift formatting, syntax parsing, Markdown lint and whitespace checks pass. The corrected test is unexecuted and is included in the proposed next combined focus. Full integrated coverage, sanitizer and leak gates remain pending. Motivation: [issue handoff](ISSUE-solar-save-set-order.md).
