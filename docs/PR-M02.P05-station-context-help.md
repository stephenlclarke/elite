# M02.P05.station-context-help: contextual station-screen guide

## Change

`StationScreenGuide` projects a help page from dock context and the existing service capabilities. `PlayerHelp` supplies the actual native dock name, equipment/market policy and main-station exchange eligibility. Limited docks retain their screen shortcuts with truthful shop/trading/exchange notices. Flight rows and the nine-row page size remain unchanged.

## Validation

Three pure Swift test methods cover eight cases: flight context with either capability value, main/waystation/headquarters pages, and independently unavailable services. They avoid simulation, save files, renderer or native journeys. The maintained GitHub unit selection adds only these three methods, increasing this feature branch's selection from339to342 without removing existing methods. Actual Swift execution and independent review remain pending.

Swift formatting, six Python report fixtures and whitespace checks pass. Documentation lint is required before push. No broad build, integration, GUI, performance, signing or release validation is claimed.

## Compatibility

No save/schema, actor ownership, service authority, prices, navigation or input binding changes. The existing station service and exchange policies remain the authority. This feature is independent of the pending station-validation memo repair and the inventory/showroom stream.

Parent: [M02.P05 / F07,F43](COMPLETION-LEDGER.md). Source and review are delivered through this feature's PR; usable-build and release evidence remain separate.

The actual canonical-base merge conflict is resolved by retaining both the three StationScreenGuide methods and three NativeStationSnapshot methods. The final maintained union is345methods. The original help source and its verified eight cases are unchanged; final-head GitHub checks and independent review remain pending.
