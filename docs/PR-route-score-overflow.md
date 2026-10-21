# Accumulate actual route scores in their final floating-point domain

`Game.routeScore` now converts positive profit and supported quantity to Double before multiplication, with a Double accumulator. All government/distance weighting and candidate selection remain unchanged. Actual selling and buying continue to use their existing bounded integer transaction paths.

A regression invokes actual auto-trade with `Int.max / 17` food and finite cash, then compares its selected route with the same single-export market at ordinary scale. It requires valid Commander/cargo/cash/market state and unchanged fuel/missiles. The former integer product traps on this supported maximum input; this is not a fabricated invalid market or a weakened cargo bound.

This slice is source-only and unexecuted. Strict formatting, syntax, Markdown and whitespace checks precede focused execution. Historical 026 validation does not apply to the changed score path. Motivation: [issue handoff](ISSUE-route-score-overflow.md).
