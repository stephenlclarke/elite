# Compile the native wormhole arrival receipt exclusively

The actual central build at 93770878e7f7a13945018743ddbbf5face2ee463 reached Game.performNativeArrival, then Swift 6 rejected the receipt assignment because its nested Commander write overlaps the Commander fuel read. Retain the actual post-arrival fuel and receipt semantics while separating that read from the write. See the [repair](PR-native-wormhole-receipt-exclusivity.md).
