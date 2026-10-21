# test: compare unordered solar equipment values consistently

## Change

Solar's final Commander comparison now independently canonicalizes actual and expected savedEquipmentInventory component/origin statistics and documented set-backed fields. A private pure helper has exactly one calling test method. Statistics must be alternating pairs with unique known ComponentAxis keys and finite non-Boolean numeric values; pairs sort by axis while retaining their original NSNumber values. Required axes must be unique known axes. Component features and origin compatibleFeatures must be unique strings and sort as Sets. The helper preserves all dictionary fields, inventory item order, receipt order, identities, grades and every value; equipment without a component remains unchanged. No actual value is copied into expected.

The original NSDictionary comparator, same six exclusions, full typed inventory equality and independent publication/save/load/world and relaunch/native/calendar expectations remain unchanged. Production encoding and gameplay do not change. The source starts directly from canonical `484085bf3f975d2b46ba8fb384fce92a9ccb9666`; prior frozen phase, parked Solar/braking and boundary refs remain preserved.

## Evidence and validation

The retained 365 failure contains twenty-one positional differences in six arrays, all representing equal statistics maps or an equal Set. Offline host parsing and independent normalization make the full retained Commander values equal, and the actual OpenStep payload agrees with plutil. The read-only diagnosis is `/tmp/elite-g2-solar365-diff/review.json`, SHA256 `597c2c2bc92cb2e49c39b070a56e3ae014c91a5529f7e376a22c86ec3877fe2a`.

Swift formatting and strict formatting lint, Markdown lint and git whitespace checks are local cold checks. Exact inverse recovery proves the entire original Solar file is recoverable by removing only the new import, helper and two comparison adapters; protected hashes cover all other tracked files. No compiler, type checking, discovery, build, test, debugger, diagnostic, simulation or native job runs in this leaf. Root reviews the full patch before G1 performs a Solar-only validation; the unchanged nineteen mining/calendar cases are not rerun. No new runtime pass is claimed. See the [issue record](ISSUE-solar-equipment-comparison-ordering.md).
