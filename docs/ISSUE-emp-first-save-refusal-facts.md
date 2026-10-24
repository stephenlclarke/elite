# EMP timer regression first-save refusal

The maintained CI run 667 at `f5e3421e029b6f2fffbbd91f5ed91c3f43335e72` observed `empArchiveNestedTimerWriterFailureRetainsArchiveAndRetries(archive: true)` throwing `invalidCommander` before the writer is deliberately blocked. The retained error does not identify whether native preparation or scene consistency refused it. No product cause is proven yet.

Keep the actual save, timer, failed-writer, pointer, archive and retry assertions unchanged. Observe the existing failed case during the next coherent affected regression run; do not add a separate diagnostic execution or weaken any validation.
