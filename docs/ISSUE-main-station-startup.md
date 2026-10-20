# Fresh commanders lack their actual starting-station berth

## Player failure and cause

Signed G02 preview 976 showed a fresh Rowan Calder in SH025 at Avenor with 720 CR, full fuel and DOCKED status, but Station Contracts refused ARLEN with `FREIGHT BOARDS REQUIRE AN ACTUAL MAIN-STATION DOCK.` Toren was also unavailable. No terms or supplied cargo could be obtained. The observed session followed the failed-restore recovery alert and Start New; it was not a successful current-save restore.

AppDelegate loads the default pack libraries, attempts startup restoration, and calls bindNewCommanderSaveIfNeeded for an unbound commander. Start New after a failed atomic restore leaves the original raw Game in place. Game.init sets resource pools and introductory presentation; GameRuntime.init(game:) prepares owned equipment. Neither creates the native world, original-main source observation, reserved actor or dock receipt. Registering the new save destination previously changed only path/durability state. Raw docked flags correctly grant no native arrival authority.

## Required repair

The explicit app new-commander boundary must create a whole approved fresh commander with a fresh equipment owner and a genuine source-owned starting berth, before destination registration. This is a born-berthed producer, not a simulated approach or doorway crossing. Its temporary original-station body registers the actual anchor/entity-one actor, resource and observation. Its final docked scene has no bodies, receipt sequence one/next sequence two, a zero physical/calendar clock and current non-serializable epoch evidence.

Keep generic Game/actor constructors and all arrival guards unchanged. A repeated unbound call may preserve an already genuine valid current berth unchanged; it must never reset owner, allocated supplier stock, cargo, quests or clocks. Bound writers and raw, foreign, replaced or destroyed station state refuse. Current valid saves continue through existing strict scene restoration and epoch rebinding. No saved trust flag, migration, old-save fallback or G04 boundary is added.

## Acceptance and ownership

The six reserved files comprise two production files, dedicated fresh-start tests, the directly affected startup-registration assertions and these paired notes. Focused qualification covers the same AppDelegate binding operation, ordinary default intro/title/status and ARLEN board/terms/Accept input, both first launch and failed-restore recovery. Additional checks cover actual finite supplied IDs, unchanged cash/fuel/clocks, current save/reload with a new epoch, second allocation and exhaustion, replay, raw-state refusal, changed authority, destination retry and writer rollback.

The dedicated six methods expand to ten cases. Three directly affected existing startup-registration methods expand to five cases, for nine methods/15 cases total. No prior pass is retained for this changed producer. Author source/lint checks do not establish executable behavior; matching owner compilation, qualification, one independent coherent review and a fresh signed player check remain pending. Companion: [PR-main-station-startup.md](PR-main-station-startup.md).

## Candidate 982 cargo-oracle correction and retained failure

Candidate 982 passed the three existing startup-registration methods/five cases, but both ordinary fresh/recovery cases failed an incorrect assertion that ordinary Machinery cargo became eight. ScriptFreightIssueAdmission.issue stores issuer-owned units in savedOwnedCargo and reserves their count in the instance payload; ScriptOwnedCargoState.valid requires payload count to equal held units. Commander.checkedCargoTonnes includes those payloads before ordinary commodities. The supplied units never enter ordinary commodity inventory.

The corrected oracle requires the entire ordinary cargo array to remain unchanged, exact original first-eight issued/held/allocation IDs, the exact freight payload of eight, occupied capacity increasing by eight and free capacity decreasing by eight. Source stock sixteen to eight, cash 720 CR, fuel and clock oracles remain unchanged. Only the two ordinary fresh/recovery cases consume this assertion; no shared helper or production code changes. The three registration methods' dependencies remain byte-identical, so their actual 982 five-case PASS is retainable.

The subsequent cold-reload method exited with signal 10 before its terminal result; five dedicated methods remain unknown. This correction does not diagnose or repair that crash. The monolithic cold method and all its helpers remain unchanged pending the owner's single existing-binary crash-stack capture. Preserve `/tmp/elite-main-station-start-982/event-stream-qualification.json` (SHA256 `3fc1f91e724dde0687adb362f85d632b566150f0ec0ab8683668df422c103333`) and closure receipt (SHA256 `f67f8439ee2d13ea649bb8b820e07cf9225834d934ac9465601881ce2252c08a`). No author build, test, probe or debugger ran. The original full clean review remains; the corrected test delta still needs focused review and actual qualification.
