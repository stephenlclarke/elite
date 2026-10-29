# test: end contact preparation before sealed impact validation

## Observed problem

The retained coverage binary from source `55d57c4f5d1e3a61562cd13c55355d54051a48ad` reproduced the full-queue stack guard failure during diagnostic run 362. Actual terminal Pulse preparation returned successfully. The later sealed impact producer entered the retained source descriptor and fit-validation chain while the contact fixture still held its scene-preparation frame.

Captured caller stack-pointer differences attribute 169,360 bytes to contact preparation and 145,616 to impact proof resolution in that chain. Those are observations at this stop, not static frame sizes or a complete peak measurement. The mapped stack had 160 bytes of headroom with a remaining probe register of 688. No stack-probe callback event was recorded. The fixed prologue allocations alone therefore cannot establish headroom or blame the already-returned terminal preparation.

## Required correction

Complete the entire existing scene-preparation phase synchronously before entering the actual sealed proof producer. Preserve all native source, archive, actor, projectile, damage, context and incident operations in their original order. Preserve every complete proof, Game and ledger oracle, including the exact 256-payload queue and replay checks. Change no production guards, thread stack, test parallelism or asynchronous behavior.

## Scope and risk

Only a private test helper boundary and paired documentation change. Source phase separation does not prove the resulting compiled frame size. Root must review the frozen source, then the integrator must inspect the new binary's wrapper and dynamic allocation before executing the original thirteen cases. See the [pull request record](PR-mission-contact-preparation-phase.md).
