# Add a validated immutable original market seed reader

The reviewed original market compiler/resources preserve 2,048 worlds and 34,816 initial quote rows but do not yet expose a native immutable reader. Integrate the reviewed loader and tests over the existing original world catalogue, authenticating the exact existing seed payload without creating live market state or switching trading. See the [integration note](PR-original-market-seed-loader.md).
