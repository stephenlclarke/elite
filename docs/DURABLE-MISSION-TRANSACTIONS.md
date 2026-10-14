# Durable mission transactions

The desktop game binds the mission runtime to the active commander save. A schema 2 acceptance, confirmation, payment, payload/passenger transfer or refit is staged and written before its effects return to the interface. Scripted native input commands use the same barrier. Opening an unaccepted offer or changing a read-only preview does not create a save.

The writer uses the existing immutable format-6 generation and atomic pointer publication. The complete candidate includes commander/property, native bodies, actual clock/timer state, event acknowledgments, operation receipts and native result envelopes. A deployed encounter and its later admission envelope cannot be separated by a crash between writes. Earlier generations remain intact.

## Failure and recovery

A failed user-command write leaves the original commander, cargo, people, cash, equipment and pending offer unchanged. The interface reports that the action was not committed. Once the save destination is available again, the same unchanged offer can be confirmed; no earlier debit or reward was published.

Autonomous physics follows a different order. Native movement, weapon consumption, hits, ordinary bounties and actual death/removal facts settle first. Lua then proposes its own business transaction against those facts. If that write fails, the actual physical state remains, the Lua instance suspends, its prior script data/receipts remain, and the unacknowledged native event stays queued. Restoring the destination and explicitly resuming the instance processes that event once. A failed reward write never resurrects a target or refunds fired ammunition.

Due callbacks run one at a time. A successful earlier callback can cancel another due timer before it fires. If publication fails, the first native firing remains queued and later Lua callbacks for that suspended instance stop; recovery can perform the original cancellation without generating a second callback first. Native safe simulation continues independently.

Explicit Save also stages pending handler work before publication. A failed Save cannot apply an unpaid pending handler to the live commander. Legacy migration is prepared and, when requested, persisted before replacing the loaded actor state. Flat legacy saves and format-4 prototypes remove the obsolete virtual Passenger Berth hardware flag while preserving the actual separately owned cabins and passengers.

## Author and embedding contract

`GameRuntime(game:saveURL:)` binds a writer. Successful Save or Load selects the new writer destination. The desktop app supplies its existing active commander path; its ordered input/save loop and main-actor preferences remain in place. There is no Lua filesystem interface.

Declare `durable-commands-v2` when a pack requires this guarantee. A memory-only runtime keeps that pack unavailable until a save destination is bound. `world.durable_commands` reports the actual current mode. Existing basic packs can still run in the explicitly memory-only backend used by tests and embeddings; the desktop game publishes their scripted transactions durably as well.

The barrier is synchronous inside GameRuntime, with no actor suspension during publication. Native input and rendering see the previous or the fully committed state. Legacy autonomous world-business/controller integration, background writer scheduling, bounded input backpressure, archival segments and explicit content migrations remain unfinished design requirements; this checkpoint is not full engine readiness.

Gallery runtimes use a fresh commander, seeded native simulation/instance stream and an independently created save namespace. Their initial state is saved before the trial runtime is returned. Subsequent automatic transactions can use only that namespace. Production saves and pack installation remain inaccessible through the trial API; redirected namespaces and linked save-generation escapes are rejected. The native Gallery launcher, retry/restart/return actions and separate Save/Open destinations are implemented for supported schema 2 packs. Complete historical world scenarios remain separate work. New saves carry a commander/gallery scope tag.

## Evidence

[Transaction tests](../Tests/EliteCoreTests/ScriptTransactionTests.swift) exercise actual disk-write denial, keyboard and mouse confirmation, initial acceptance rollback, cabin purchase rollback, pending-handler Save rollback, durable encounter/result publication, queue-capacity admission rollback, timer cancellation/recovery and real laser death with deferred once-only reward. The tests use isolated temporary directories and original demonstration packs, not historical mission acceptance claims. The complete gate record is [SCRIPTABLE-MISSION-VALIDATION.json](SCRIPTABLE-MISSION-VALIDATION.json).
