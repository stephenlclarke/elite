# Salvage fixture must reserve its wreck ID and read the actual save format

Full 222 reports `SaveError.invalidCommander` in the existing partial-cut/current-pose save method. Its shared fixture inserts body ID 88 without advancing the scene allocator, while current versioned persistence validates `nextBodyID` against actual body IDs. The save test also assumes raw Commander JSON despite the genuine native-world/versioned save path. This is source-backed setup diagnosis pending focused execution; it does not establish the exact thrown guard from the active run.

Reserve the fixture body ID, use the actual versioned reader and retain the original exact cut progress, current wreck pose and equipment ownership assertions. Remove the complete isolated save directory, including its retained generations, after execution. Do not weaken save, world, native station or allocator guards. See [the correction](PR-salvage-versioned-save-fixture.md).
