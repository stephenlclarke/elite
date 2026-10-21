# Solar equipment comparison depends on unordered encoding

## Problem and evidence

The retained 365 run on canonical `484085bf3f975d2b46ba8fb384fce92a9ccb9666` passes all thirteen mining and six calendar cases. Solar reaches its original final NSDictionary comparison after its full typed equipment inventory, save/load, parked NPC, native world and calendar checks, but that comparison fails. Offline analysis of both retained Commander payloads identifies twenty-one positional differences in exactly six equipment arrays. Five arrays encode enum-keyed statistics dictionaries and one encodes the required-axis Set; their semantic values are identical. Independently canonicalizing only these six arrays makes the complete retained Commander trees equal. This evidence shows a comparison representation defect, with no observed saved value loss.

## Expected behavior

The Solar test must compare every retained Commander value while ignoring dictionary and Set iteration order only where the equipment model documents those unordered types. Item and receipt order, identity, grade, features and all numeric statistics must retain their existing comparison coverage. The original final comparator, original six exclusions and full typed inventory equality must remain intact.

## Scope and risks

One Solar test file and this documentation pair change. Production persistence, all other methods and shared helpers remain frozen. A malformed equipment JSON shape must fail rather than silently disappear during normalization. This cold source leaf has formatting and scope checks only; G1 owns the later Solar-only compilation and execution after Root review. See the [implementation record](PR-solar-equipment-comparison-ordering.md).
