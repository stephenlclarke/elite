# Issue63: codec fixtures must follow the native envelope lowering

The charter-audit and network-certification fixture positives pass the outer archive schema directly into NativeWayfarerInductionSave, although the production preflight first lowers it through NativeInductionArkSave.lowerSchema. Valid originals therefore refuse at the wrong version gate. The unknown-field negatives hit that same wrong gate instead of proving closed-field rejection.

Use the production lowering for both positive and unknown-field-negative lower-validator calls. Keep actual outer versions on NativeInductionCrewLogSave and retain every earlier/embedded/misplaced/unknown refusal. Do not widen production schemas, remove assertions or change the selected method count.

Refs [issue63](https://github.com/stephenlclarke/elite/issues/63). The independent SIGNAL4 exit in issue60 has no attributed cause; this fixture error does not establish its cause.
