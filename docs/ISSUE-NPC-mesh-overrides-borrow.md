# NPC beam mesh query exhausts the retained worker stack

The actual935 capture stops at `Game.gameplayMeshOverrides` under `nearestMissionCollision`, NPC beam preparation and the unchanged two-pulse native Cobra EMP test. The getter retains an owned `SpaceBody` loop value; its observed frame spans 8112 bytes. Callers already retain larger collision, weapon and movement frames.

Root approved only indexed iteration with a borrowed predicate in that getter. All five eligibility checks, order, mesh selection and dictionary overwrite behavior remain unchanged. No caller, weapon behavior, state representation, fixture or default stack change is authorized.

Base `9bf2b1a671951867fd7b668cdd8082eff50ec48c`; owner MC1 through Root. Source prepared, execution UNRUN. G1 owns one composed matching build and finite qualification; no frame reduction or runtime PASS is established yet.
