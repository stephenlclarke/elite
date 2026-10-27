# Observe actual EMP charge outcomes without changing native flight

This leaf changes one shared test helper and paired notes only. Primitive counters recognize actual new saved start times and released/cancelled terminal times. They do not write any simulation state. The identical continuation Boolean remains evaluated once and required true. Its failure-only message adds the observed counters, last actual charge phase/start/end, EMP audio-event count, existing pre-tick contact/ready flag/requested controls, selected tool and suspension latch, and pre-tick target shields/electrical charge from the already-captured body.

No collision query, whole Game/Commander dump, damage/resource edit, elapsed-time jump, target replacement, input change, fitted device, stack override or budget waiver is added. Original targeting/control calculations and all later actor/crew/law/travel/save assertions remain unchanged. Geometry's positive pitch/yaw conventions already match the helper; no sign change is justified by the evidence.

Source formatting/parsing, strict lint, Markdownlint, whitespace and exact diff/hash correspondence precede Root review. The proposed diagnostic selects only the same two original native methods/three cases in coverage/debug/default parallelism under the original 600-second command and 640-second supervisor. Execution remains pending review. Forty completed passing 339 scopes are retained; no full CI, sanitizer, leak, native-success or release claim is made.

[Issue](ISSUE-emp-charge-outcome-diagnostics.md).
