# Check showroom field units before accepting a shared profile group

The compatibility helper now requires both fields and matching unit strings before applying the existing same-group or permitted cross-profile capacity rules. SH023's unitless charter source field and SH169's berth field remain visible with their original text and provenance, but receive no invented better/worse benefit or numeric difference. Matching blank units continue to compare normally; no unit conversion or metadata normalization is introduced.

Production scope is only `CurrentShipComparison.swift`. Existing native precision, source values, physical-capacity whitelist, baseline direction and comparison projections are retained. Renderer, geometry, common 3D orientation, equipment-transfer and exchange transactions, Game/save schemas, CI/selectors, catalogue resources and Root's ledger are unchanged. The reviewed ac3a76b6 packet remains frozen independently.

Three focused methods cover the real SH023/SH169 mismatch in both directions with unchanged displayed text and Commander; matching blank units and explicit berth units with same/better/worse controls; and native halfway precision, absent fields, mismatched speed units, all seven allowed cross-profile capacity units, forbidden reverse/native-source comparisons, engine pools and nonfinite native ratings.

Standalone formatting, Markdown/whitespace and bounded static source/resource checks are the validation boundary. All three new Swift methods remain UNRUN and unselected. No compiler/native/GUI/media/probe/sanitizer/test execution, publication or merge occurs while G1 owns M01. Independent source review and assigned focused execution remain before integration. [Problem](ISSUE-showroom-unit-compatibility.md).
