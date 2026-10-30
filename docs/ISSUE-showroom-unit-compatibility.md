# M02.P04 / F06: require matching units before showroom benefit ratings

The showroom compatibility helper currently accepts every field pair sharing a profile group before checking the units. In the real project-refit-v1 source profiles, SH023's initial charter field is `0` with an empty unit while SH169's field is `1 berths` with unit berths. The comparison assigns a better/worse rating from those numbers even though its numeric-difference function refuses the mismatched units. A shared profile group alone does not establish a conversion or equivalent measurement.

Require matching unit strings before the existing group and cross-profile rules. Keep matching empty units valid, retain the existing physical-capacity cross-profile whitelist and do not convert units or change catalogue metadata, charter grants or fittings. This packet is independent of the reviewed native rounded-hint fix at ac3a76b6. [Implementation](PR-showroom-unit-compatibility.md).
