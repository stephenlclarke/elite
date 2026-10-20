# Match station fixtures to the selected hull and actual native anchor

Initialize launch fuel from the selected hull and require a valid successful launch. Retain the actual current main-station anchor and body identity; use the existing observer reframe to place each requested station-local pose and verify its position and axes.

All six starts, requested spin/speed/axes and existing clearance/collision/docking assertions remain intact. Four directly affected methods are selected for the shared qualification build. Tests and independent review are pending at this source freeze. See the [issue](ISSUE-station-native-fixture.md).
