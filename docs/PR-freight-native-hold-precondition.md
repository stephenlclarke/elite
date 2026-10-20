# test: retain native hold capacity in freight stale-quote fixture

The freight stale-confirmation fixture now requires its original100000-unit budget without imposing an incorrect20-tonne hold on native SH023. Its existing paid market loop uses actual standardCargoCapacity and proves remaining space is smaller than the generated freight quantity before confirming the stale quote.

The test source is the exact reviewed failed648369f5 version with only the unsupported capacity conjunction removed. All quote, paid fitting and purchases, refusal, complete Commander and file rollback, and empty-instance assertions remain unchanged. Production code, shared helpers, starting resources and catalogue values are unchanged.

Source conservation, formatting and Markdown checks are performed before freeze. Independent causal-delta review and one matching focused runtime qualification remain pending with Root/G1 after the G08 candidate handoff. No passing runtime, integration, whole-suite or release claim is made. Actual1050 remains the failure record; source-only diagnosis is retained at /tmp/elite-g2-1050-source-diagnosis/SOURCE-DIAGNOSIS.json. See [motivation](ISSUE-freight-native-hold-precondition.md).
