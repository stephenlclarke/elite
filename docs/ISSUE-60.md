# Issue60: bounded fixture construction stack use

The matched crash report for certification commit 60c9 / run 39752843346 identifies a 544 KiB stack guard on thread 1 while JSONEncoder hashes a flight reception during deeply nested fixture construction. Earlier SIGNAL4 runs without a matching report remain unattributed.

Reduce nested test-value frame pressure by changing the eight remaining immutable fixture containers to final classes. Preserve every constructor body, identity, receipt, assertion, test selection and production rule. This is a source-directed correction for the matched construction path; only an actual successful hosted run can establish runtime qualification.
