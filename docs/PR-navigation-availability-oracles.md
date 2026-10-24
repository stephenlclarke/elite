<!-- markdownlint-disable MD013 -->
# test(navigation): align exact availability refusals with installed route guidance

The navigation availability test expected the obsolete generic endpoint-binding message at three assertions. Its expectations now match the existing distinct route-record restoration and chart-selection messages. All exact equality checks, explicit-binding exceptions, applicability and durability priorities remain in place. Production navigation behavior is unchanged.

The maintained isolated-unit selection now includes both existing navigation availability methods. Its completeness fixture increases from346to348methods without removing any selection. These methods expand to four cases. Six Python report-completeness fixtures pass. Focused Swift results are recorded in the related [rescue/query repair note](PR-rescue-acceptance-frames.md); no whole-project qualification is inferred from source review or these Python fixtures.

This fixes [issue #113](https://github.com/stephenlclarke/elite/issues/113) as part of [PR #107](https://github.com/stephenlclarke/elite/pull/107). No save, equipment, mission or gameplay compatibility changes are introduced.
