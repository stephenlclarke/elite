# test(salvage): reserve fixture identity and read versioned save

The existing cutter fixture advances `nextBodyID` past its explicitly inserted wreck ID 88, preserving a larger existing cursor. The explicit-save regression uses an isolated directory, requires the actual schema-21 pointer and reads Commander through `ScriptSaveStore.read`. Original exact progress 0.1, current moved wreck pose and equipment-inventory assertions remain unchanged. Cleanup removes the directory and its generation files. See [the problem](ISSUE-salvage-versioned-save-fixture.md).

Only test setup and reading change; production save validation, scene consistency, native custody and allocator behavior stay intact. Reversing these deliberate setup/reader edits reconstructs the entire original test file. Independent source review is clean; focused/full runtime verification remains pending while the frozen 222 attempt completes; no passing or exact thrown-guard claim is inferred from source inspection.
