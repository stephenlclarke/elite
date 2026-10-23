# feat(fleet): stage original Eagle Cruiser capital binding

Held draft; M01 source consolidation is now the active priority. Preserve this work without treating it as qualified integration.

The implemented source binds SH043 to its individually pinned original metre model and never-purchase mechanics: 172t cargo, 70t expansion, energy1490, shield600, 14-LY tank, 7-LY drive, ten pylons, 18-second spool and unpriced zero value. The shared projection admits never-purchase only for a retained non-purchasable military capital vessel with a destruction milestone; normal blueprint projections stay separate. It preserves capital status, destruction collection, historical fields and the retained 52-person project crew estimate. Shared accommodation wording no longer incorrectly assumes one commander for every hull. Availability labels never-purchase hulls as not for sale; trade refusal logic is unchanged. Raw assets and original specification records are unchanged.

The physical contract and native player route are implemented. Existing closed-set expectations now include only this new original registration, while parameterless positive-price validity remains false and explicit never-policy validity admits the authored zero. README records the capital as not for sale.

Remaining work is explicit: dedicated per-hull positive/negative authentication tests; complete physical/player appearance checks; cargo/crew/mount and prior-blueprint projection cases; actual quote refusal and destruction-without-blueprint component cases; syntax/formatting qualification and actual Swift execution/review. No dedicated Eagle tests are authored or selected yet. The retained425-method selection is unchanged; six Python report fixtures pass. Syntax parsing, strict formatting, Markdown and whitespace checks pass only as authoring checks, not compilation or component qualification.

This draft stacks on Saker72a2ded9 and must not be merged while held. No full-hull, M14, actual flight/docking, coverage/sanitizer/leak or release claim is made. No README media changes or integration run.
