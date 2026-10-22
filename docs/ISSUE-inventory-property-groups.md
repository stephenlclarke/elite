# Distinguish protected property from equipment in Inventory

Ledger M02.P05.inventory: the current Inventory projection places its equipment heading before measured-extraction, SENN and PELL original-property rows. Those protected originals are therefore presented as fitted or held equipment. Ordinary commodities, reserved space and owned equipment also lack clear separate category boundaries.

Use explicit trade/hold, protected-property, fitted-equipment and held-equipment sections. Retain original quantities and custody notices, installed lasers, equipment identities, provenance and exact typed action previews. Protected/reserved tonnes must not become saleable cargo or fitting actions. Existing alien and salvage categories remain separate.

Acceptance is a pure projection: mixed cargo keeps its amounts and distinct boundaries; every owned item retains exactly one subject and its original preview in the correct fitted/held section; empty and legacy custody stay explicit without invented items or actions. No cargo, equipment, mission, save or command semantics change.

Review finding [#52](https://github.com/stephenlclarke/elite/issues/52): the legacy-laser assertion incorrectly expected leading indentation that the existing text wrapper removes. Actual hosted run39735189170 executed244 methods:243 passed, with four whitespace assertions failing in the one legacy test. Match the unchanged actual laser summary text; preserve every legacy/empty-storage/subject assertion and production behavior.
