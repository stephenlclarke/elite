# Native ship panel colour allocation

Every nonempty panel in the native drawing path constructs the same immutable `CGColor` separately for its fill and stroke. Reuse one local value to remove one colour construction per visible panel while preserving the existing conversion and every drawing command. This is a supporting optimization; the measured native drawing bottleneck remains unresolved.
