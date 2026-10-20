# RRS fixture requires a current two-kind station source

CI934 on `485fab55293ca984e38b3c88659e3712a601b12b` throws `invalidState` from the shared launch fixture before the malformed-save owner, duplicate and adapter cases run. G01-S237 is now Anarchy and declares headquarters only, contradicting the fixture's two-station requirement.

Use current G04-S149 (Lolodor, Democracy), which declares one headquarters and one waystation. Preserve real launch, both station-kind cases and all save-forgery/rollback assertions. No production, default hull/fuel, geometry or source-placement policy change is needed.

Owner MC1, through Root. Isolated base `bac6e79a9b386d30bae55959536013a7e8fca2be`; executable fixture source `a4698c5a440a693afa3b67cd145a09cec1c737b5`. Shared936 built composed `c7c4137097d4ecfbdec84db9fe1bd1b645a4a911`, whose complete RRS test file is byte-identical to this fixture. Actual939 passed both focused methods/all five cases: malformed owner/duplicate/adapter saves preserve live state and files, and both waystation/headquarters docked saves restore correctly. Evidence: `/tmp/elite-remaining-fixtures-939/event-stream-qualification.json` and `owner-outcomes.json`.

G1 reports actual whole-process closure and unchanged protected inputs. This qualifies only the RRS two-method/five-case selection. The EMP crash remains unresolved, and other station-method outcomes are separate; no overall CI or playable completion is claimed. Independent coherent review of the RRS test file and paired notes remains pending before G1 acceptance.
