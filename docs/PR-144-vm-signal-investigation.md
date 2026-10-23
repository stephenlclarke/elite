# Retained VM SIGILL investigation

Run39980120332 at e2f0498c failed with signal4 after247.50s compilation,
zero completed methods and unfinished XML. The matched normal report records
PID11079, image BAAAE1A6-A8F2-3452-8DC8-2A65E93207FB, SHA256
7fe62715254c5efd75431046d832c4d20f9e8cc385fd944d6907ccb886b01333.
The selected thread was decoding retained Kite historical ship data through
Array growth. EXC_CRASH/SIGILL has zero exception addresses; its captured PC
is an ordinary MOV, not a BRK/UDF. No guard mapping, trap reason, shared decoder
bug or hull-data defect is established. This is issue144, not142 or95.

A distinct Cocoa260 observation in the audit writer fixture is fixed under145.
Buffered timestamps do not establish that its error caused SIGILL. Repository
observers are read-only and their cleanup uses TERM/KILL, not SIGILL; no
repository or external signal origin is proved.

One exact-image VM diagnosis ran the sampled Kite method under LLDB using the
original Swift6.1.2/Xcode16.4/SDK15.5 and resource bundle. It completed18.482s;
wrapper22.658440s/exit0. A finite paired diagnosis then selected only that Kite
method and the original unpatched audit writer method: audit reported Cocoa260
at10.860s, Kite completed18.730s, and the helper exited normally with code1.
The diagnostic wrapper/transport exited0 after22.110094s. No SIGILL reproduced.
Neither diagnostic is normal unit qualification, a fix, or full-batch evidence.
No rebuild, stack change, decoder rewrite or whole524 replay was used.

Records: `/tmp/elite-mba-e2-unit39980120332`,
`/tmp/elite-144-e2-vm-diagnostic`, and
`/tmp/elite-144-e2-vm-pair-diagnostic`. VM copies remain separately retained.
Issue144 remains unattributed. The next changed-fixture gate must retain all
524 original selected methods; any successful result must not be relabelled
as proof that145 causally repaired this signal.

## Preserve module slides in future existing owned captures

Current combined285/eb5 evidence confirms the saved owned-capture image list retains UUIDs/paths but omits load addresses/slides. When no matching normal report exists, raw game PCs cannot be authoritatively mapped from those records. No mapping may be guessed from old captures, current processes or unproven main offsets. This is an evidence completeness defect; it does not establish the cause of historical SIGILL or current SIGBUS, or imply they share a cause.

Add only the standard image-list offset flag to the existing fault-output command: image list -o -u -f. Local LLDB help confirms -o emits the image load offset from its base file address (slide). Keep the same minimal thread/frame formats, UUID/path metadata, first-fault observation, identity matching, detach/cleanup, capture count/budget and original exit status. Update the existing protocol fixture expectation and run existing capture tests. No new workflow, target run, probe, replay or Swift source change is introduced; old captures remain unchanged and cannot gain missing information retroactively. Issue144 remains open and unattributed.

The existing capture suites passed70 tests (unittest0.155seconds; wrapper0.281966667seconds/exit0) with tool blob050d3716acf4eaa8aba7334a1e4dc01310c7de22 and protocol fixture98288f6fe6a694f9b43ea9bfd30eea29c0a151ec. Receipts `/tmp/elite-m01-capture-metadata-tests` retain command/log/result. No Swift/game test or new diagnostic target ran for this metadata correction.
