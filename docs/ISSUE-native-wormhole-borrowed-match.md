# Compile the borrowed native wormhole passage match

The actual central coverage-enabled build at 66ba61d599c26b4687eb7ca76d99e80074231469 failed before tests: Swift 6 rejected NativeCommanderWormholePassage.matches because its Boolean conjunction autoclosures consume the borrowed Game. The sealed passage authority checks must retain their order and behavior while compiling under actor-isolated Swift 6. See the [repair](PR-native-wormhole-borrowed-match.md).
