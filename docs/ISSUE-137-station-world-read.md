# Station world reader copies Commander

Issue: <https://github.com/stephenlclarke/elite/issues/137>

The retained original push run39948240459 at2948a61e failed with SIGBUS
before any unit completed. Its matched IPS attributes a stack-guard fault to
an outlined Commander copy in Game.swift's station-world reader. The original
evidence remains retained; the unfinished report is not a unit pass.

The repair projects the address of the stored nativeStations property through
UnsafePointer.pointer(to:) before reading its value. This removes the large
Commander receiver copy at that boundary. The reader remains synchronous;
policy order, absent-world handling, complete validation and all existing
regression assertions are unchanged.

Validation: strict swift-format and git diff --check pass. Independent source
review and completed affected-unit evidence remain pending. Packaging and
playable M01 acceptance remain on hold; this document claims neither.
