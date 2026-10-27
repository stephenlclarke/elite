# Compile the native wormhole arrival receipt exclusively

The actual central build at 93770878e7f7a13945018743ddbbf5face2ee463 reached Game.performNativeArrival, then Swift 6 rejected the receipt assignment because its nested Commander write overlaps the Commander fuel read. Retain the actual post-arrival fuel and receipt semantics while separating that read from the write. See the [repair](PR-native-wormhole-receipt-exclusivity.md).

The next actual build at 8566ac21346969572b40c84ddd34f432b46ecfdb reached the departure provider and rejected the retained optional NPC velocity read during its own write. Its existing inverse-anchor transform likewise needs a local value before mutation.
