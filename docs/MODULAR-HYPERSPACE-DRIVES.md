# Modular hyperspace drives

Source implementation; integrated compilation, runtime and full CI acceptance are pending.

The ordinary drive is an actual owned component in the drive slot. Basic is intrinsic, Intermediate costs 5,000 CR at displayed tech level 10, and Advanced costs 15,000 CR at tech level 13. Buying requires the fitted predecessor and its paid progression. Charge times are 10, 5 and 1 seconds before the fitted navigation multiplier. Hyperspace mass lock uses 100%, 80% and 60% of the original ship/celestial distances. In-system jumps, finite fuel and navigation range retain their independent rules. XYZZY grants Advanced.

Existing inventory versions migrate explicitly to equipment version 3, retaining every owned item, UUID, acquisition receipt, balance, cargo and fuel value. As a project migration choice, one validated born-stock Basic drive has a reserved place beside the ordinary 256-item pool. Its standard provenance, physical/component UUID, immutable Basic origin and validated progression must agree. The reservation follows that same item through earned promotion, storage and transfer; paid, reward, alien and duplicate foundations receive no additional place. Ordinary admissions remain bounded at 256.

Actual saves first prepare the inventory and establish the existing calendar boundary, then publish schema 25 or a later composed version. Raw and older versioned headers refuse the new fields; a mid-jump first save retains the untracked-legacy journey marker. Inventory charge readouts use drive seconds and navigation ratios once, separately from the preserved original ship catalogue values.

Eight authored regression methods cover the real stock item, paid shop progression, finite-fuel H travel, independent in-system safety, native versioned save/downgrade, legacy migration and full-pool/promotion reservation. No execution is claimed here. Alien immediate travel remains a separate salvage and authenticated PLUGH fitting task.
