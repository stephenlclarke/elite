# Refuse purchases beyond supported cargo bounds

## Implementation

Manual buying now checks the existing per-commodity save bound before debiting credits or changing cargo/stock. Market availability reports a full hold at that bound and uses `tradeCargoCapacity` for tonne commodities, matching actual purchasing when cabins or contract fitting constrain nominal unlimited cargo. Selling, prices, route planning and automatic trading are unchanged.

## Validation

Three regression methods cover seven cases through `GameRuntime`: refusal at the supported limit, acceptance of the last unit followed by refusal and a genuine save/reload, and an actually fitted four-cabin hold. Formatting and Markdown lint passed. Root150 compiled and passed all eight selected market/hold compatibility methods at `44960dd5f119134fc874f20a59e51f9de584bdcc`, including all seven new actor cases. The maximum accepted quantity survived actual save/reload, and refusal conserved the whole commander and market. Source, human save and preferences were unchanged and all owned processes exited.

## Compatibility

Existing valid saves remain accepted and the save format is unchanged. This fixes an edge case without lowering the accepted quantity bound or rewriting saved cargo. Full coverage, sanitizer and leak gates remain separate acceptance requirements.

See [the issue](ISSUE-market-cargo-bounds.md).
