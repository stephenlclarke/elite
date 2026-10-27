# EMP archive buffers overlap real crew-pod admission

No-rebuild diagnostic 278 used the exact compiled 277 binary, `45ad009ba59d19c16a55bc4b8e9120b57474e7cd0ee55654d2366faa622bc2c9`. The unchanged scene-revisit regression had progressed to actual scheduled crew ejection when `populateNativeStations` entered a mapped stack guard through encounter admission. Its physical caller frames included `advanceEMPActors` at 89,952 bytes, `ejectOneEMPCrewMember` at 115,504 bytes, encounter admission at 48,304 bytes and actor preparation at 51,184 bytes. Diagnostic completion is not a test pass or proof of the original signal's cause.

Archive coasting and per-source readmission retain complete saved records in the same function that subsequently admits a new occupied escape pod. Separate these completed phases before entering crew ejection, preserving the exact original decisions, custody, order and atomic admission. See [the source change](PR-emp-archive-phase-lifetimes.md).
