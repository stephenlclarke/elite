# CR-09: Malformed mining state can enter saved commanders

MiningLedger previously synthesized decoding without collection bounds or invariant checks, and Commander.valid omitted its optional saved mining state. Altered saves could contain negative partial energy, mismatched payload keys, impossible ore or incoherent physical bindings. These could strand cargo or change depletion behavior after Load.

Decode bounded collections incrementally, reject duplicate keys and invalid canonical mining state before publication, and retain compatibility with commanders that omit the optional field. Implementation and validation: [handoff](PR-CR-09-mining-save-invariants.md).
