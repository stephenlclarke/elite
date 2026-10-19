# EMP unit boundary leaves native station spin behind its clock

Focused run 669 completed without a crash but the archive-enabled first save in `empArchiveNestedTimerWriterFailureRetainsArchiveAndRetries` was refused. Its bounded diagnostic proved native preparation and world structure valid, then identified `sceneStations` at physical time 10. The refusal is retained; no commander, EMP custody or writer validation should be weakened.

`empFixture` invokes `ensurePhysicalActors`, which adopts its ordinary target and populates authentic native rescue stations at time zero. The explicitly controlled `releaseDamagedEMPBoundary` fixture then advances physical time by ten seconds without a physics frame. Existing waystation bodies retain zero model rotation while their authoritative current source phase is 0.2 radians. The strict rigid station scene check correctly refuses that inconsistent unit scene.
