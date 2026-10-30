# Medusa loadout correction - revision 2.1

This section records the earlier 2.1 handoff. Current author revision 2.2 is the [bounded review correction batch](REVIEW-CORRECTIONS.md), supplied as `fleet-design-v2-20261030-r3.zip`; prior archives remain historical.

The orchestrator relayed Stephen's newer explicit clarification after the first design handoff. Consume Mission Researcher commit `a91c899589e226c01adb180c4bee6b162cb0ee67`, frozen-packet SHA-256 `ae837946fe3ddd5e8af0cfa07bdb25ab90a35878ab132c75efedd9f602e03118`.

The four configurations are stock catalogue baseline, limited beatable mission fit, actual paid PLUGH stock purchase, and the player's actual paid maximum upgrades. Restore all stock SH171 fields from the source: notably energy410/shields300/speed50.3/range9, price288000CR, one commander and 13 stock equipment units. The earlier 80/2000/800 etc. values and 32 units survive only as candidate paid endgame targets, with exact upgrade/fitting nodes and native comparative proof pending. Remove the full-strength-donor requirement and all twelve-stock-stat superiority checks.

This correction changes only this new fleet-design folder. The other 170 per-hull TOMLs, Tithe variants/functional names, original geometry, unrelated primary-checkout WIP, current runtime and existing coder reservations are preserved. Root decides any future import, push or assignment; none is performed by this session.

The original archive `fleet-design-v2-20261030.zip`, SHA-256 `45318e4de6de4b1e2e2fe959c39c07f9afbcf4f3054e753d4bc590089ebe4cb4`, remains historical and must not be imported as current. The replacement is `fleet-design-v2-20261030-r2.zip`; its exact delivery receipt records the corrected manifest and archive hashes. This is a narrow documentation/design correction, not a new gameplay workstream or a claim that the player-max comparison has passed.
