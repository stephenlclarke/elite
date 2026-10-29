# Bring native save fixtures into the current versioned contract

Validation 316 exposed three existing native save caller failures. The unchanged-fixture diagnostic 317 proved that docked NPC and absent-salvage saves are valid schema-26 pointers: the official reader and actual runtime load succeed, the whole restored Commander equals the saved live value, and file bytes remain unchanged. First save adds the required current mining policy and calendar. Direct Commander decoding of that pointer is an obsolete file-format assumption.

The flight NPC fixture separately creates body 40 while retaining the default next-body highwater of 10. Actual Commander validity and world consistency pass, but world validity fails before and after native preparation; the real save correctly refuses it. Keep the production world guard and establish proper fixture allocation instead.

The repair must retain complete Commander, NPC resource, reference, original-key and absent-ledger assertions. Establish current policy/calendar before capturing preservation expectations, use actual spawn allocation and a correct body highwater, and read current saves through the authenticated versioned reader. Keep raw serialization and raw authority tests unchanged. Independently test the legacy native migration and required policy/calendar additions without copying saved results into expected values.

[PR-native-save-callers.md](PR-native-save-callers.md).
