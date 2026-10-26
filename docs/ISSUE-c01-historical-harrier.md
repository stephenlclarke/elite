# Preserve C01 Harrier independently of the live SH056 slot

## Motivation

C01 loads its Harrier from `ShipCatalogue.ship("SH056")`, then requires the historical Harrier name, ROC-SH056 model and valid design. The future Meridian SH056 Aplomado activation will replace that live record. C01 must continue to use its historical mission model without borrowing Aplomado geometry or changing calibration, collision, appearance, permissions or saved model hashes.

## Scope

Start from published, independently source-reviewed and hosted-unit-qualified Jaguar `bb3c437945d5b650e84adaa077e6c5c240ef9d93`. Read the existing retained `Resources/Ships/SH056.toml` with the existing catalogue decoder, independently of live activation. Keep the name/model/design guards and add the source ID check that the live ID lookup previously supplied. Reuse the complete existing geometry builder, 65-metre uniform calibration and convex-envelope algorithm unchanged.

The retained file is available: SHA256 `06f2f19f731014a2df41122b2669a0919af1535acd7fc9baa595789a7233825d`, Harrier / ROC-SH056, 1,426 vertices and 1,065 faces. Its bounds are minimum(-21.02621,-7.79609,-32.5) and maximum(21.02621,7.79609,32.5); the current uniform scale is exactly one. No substitute geometry is authored.

## Acceptance

Four new pure component methods cover complete design/appearance and canonical model bytes, exact calibrated bounds and closed conservative collision, refusal of real Aplomado geometry and its hash at the C01 authentication boundary, and foreign/malformed historical records. All 676 parent methods remain selected; adding four gives 680. Existing C01 tests and all their assertions remain unchanged.

## Limits

Hosted run 40399461150 on `395a97e3` failed compilation before tests: the new fixture used an unavailable zero-argument `Vector3` initializer. The intended zero position is now explicit as `.init(0, 0, 0)`. All production, test assertions and selection remain unchanged; corrected-head qualification is pending.

This is an isolated prerequisite for future M04.H056, not SH056 activation or a mission/release completion. The existing C01 surveyor fixture still names live SH056 Harrier; the future activation owner must update that explicitly bounded fixture when activation occurs. No shared catalogue API, generated/raw asset, fleet registry, C08 recorder source, mission permission/authentication/schema, current M01/release or main changes are included. Root owns integration timing and the completion ledger.

See [implementation and validation](PR-c01-historical-harrier.md).
