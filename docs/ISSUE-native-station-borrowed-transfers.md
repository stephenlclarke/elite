# Compile borrowed station transfer validation

The actual corrected central build at 55fada812b64da5ea1163f43168c62218501de5f compiled past the wormhole passage repair, then Swift 6 rejected PreparedStationTransfers.init: the allSatisfy closure consumes its borrowed Game. Keep the same bounded proof validation, refusal order and staged ownership without a closure capture. See the [repair](PR-native-station-borrowed-transfers.md).
