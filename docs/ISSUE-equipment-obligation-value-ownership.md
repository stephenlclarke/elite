# Whole mission values in equipment-obligation sorting

The exact retained run 510 on `6f9293c151af8c22ac527194e207509e836cca21` stack-overflowed in sequence copying and `sorted(by:)`, reached from `Commander.equipmentIssueObligations`, `issuedEquipmentValid`, Commander validation and the unchanged mission acceptance/retention path. The campaign validator had already returned; this is a separate concrete equipment validation fault, not a retention pass.

The obligation collector sorts whole dictionary elements containing `ScriptInstance`. Its issue validation then passes that full instance although the predicate reads only its ID and digest. The final native-inventory provenance join also binds the whole instance. These values contain unrelated campaign, mission and world data that should not travel through generic sorting or the equipment issue predicate.

Sort stable keys in the exact original order and read fresh narrow current-member values. Preserve all mission/resource address checks, full record validity, obligation conversion, native inventory/duplicate/provenance joins and thrown errors. Suspended or missing-content issues remain included; empty issue lists do not bypass validation. Legacy and mutation semantics, schema, actor ownership and candidate rollback must stay unchanged.
