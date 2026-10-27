# Borrow commander for record selection facts

Public CI 39563253358 stopped in the recordRecoveryFacts reader while ordinary station targeting called recordRecoveryMetadata and workTargetCandidate. G1 retained the actual selected fault thread and matched native image/dSYM UUID 73828011-F1F7-3CC8-94A9-EC202BF3FD7A. The tested merge source and public fault-path inputs match; the failure is separate from the earlier commander query and pledge readers.

The facts reader combines an early alias rejection with repeated commander reads for source, mission, carrier and fit. Compiler temporaries can be reserved before that guard executes. Keep the existing alias and alias-index checks in the outer reader, then use the established bounded body-copy pattern and synchronous withReadOnlyCommander accessor to call a private non-inlined helper. Its borrowing Commander parameter supplies the remaining reads.

The remaining state, source, active mission, loss, reception, carrier, context and logical actor guards and returned facts retain their exact expressions and order. Alias, metadata, mesh and state readers remain unchanged. There is no state mutation, ownership, authority, storage, representation, schema or pointer-escape change.

MBA formatting and strict lint pass. The inverse source check restores the whole original file. G1 owns matching compilation and the three existing station fault, real identification and alias-forgery cases. One full three-path independent review follows actual native PASS. No frame-size or hosted CI repair promise follows from source checks alone.

Actual pure-public matching compilation1234 PASS (78.72seconds). All three unchanged methods/cases1235 PASS, final13.014seconds, zero issues or unknown outcomes; runner17.178794seconds, outer19.248114seconds. All ten observed owned starts close naturally; source/preferences and2010 retained artifacts stay exact. Complete three-path independent review CLEAN, SHA256cf593af83b0a078155dd7b398c394e38bb2ed8e613fa7d4deb3669695806b220. Integrated at a9e561db. Final public CI and required PR review remain pending; focused results do not establish measured stack savings or hosted repair.
