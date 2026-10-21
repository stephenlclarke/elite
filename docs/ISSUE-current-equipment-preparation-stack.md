# Current equipment preparation during durable timer publication

The unchanged two-timer smoke on committed source `d11059f88d27ed40589ff737fb19918c699f25fa` exhausted a 544 KiB thread stack. The matched run 457 crash reached `migrateStockHyperspaceDrive` through `prepareEquipmentCandidate`, `prepareEquipment`, native save preparation and the original durable timer callback. This is an actual crash, not a test pass.

Current preparation always entered a whole-Commander candidate frame. It then called stock-drive migration even for version 3, entering its value-heavy body before validation and the current-version return. Retained compiled-object observations confirm copy witnesses on this path; stack-probe relocation counts are not stack-byte measurements.

## Required behavior

Validate every already-current inventory, history, finite-ammunition mirror and effective statistic without entering allocating migration bodies. Preserve invalid-state refusal, mixed-representation checks, public preparation/migration failure atomicity and all historical migration semantics. A genuine migration must still retain owned identities, history, money, resources and finite ammunition, and publish only after complete success.
