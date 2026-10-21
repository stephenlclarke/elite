# URL aliases corrupt retained diagnostic manifest keys

The retained continuation diagnostic in run 548 stopped before copy, load or work when its exact input-manifest guard failed. All 25 retained files and their payload hashes were unchanged. No held-work or later-stage evidence was collected.

The single pure Foundation preflight 549 reproduced the actual discrepancy. The resolved directory URL reported `/tmp/elite-native-journeys-focused-542/retained-save`, length 52, while file enumeration returned `/private/tmp/elite-native-journeys-focused-542/retained-save/...`, whose physical base prefix has length 60. Trimming 53 characters from those file paths left `ed-save/` on every relative key, including `ed-save/commander.json` instead of `commander.json`.

The actual 25-entry payload was 3928 bytes with digest `c6ce3267aa6d6d09eb54f06c63432b6335825914082049f3cc1ed4bd7d21889e`. Every payload hash matched after correcting only the key prefix. The correct 3728-byte encoding produces the original required digest `977264133e75c7900694f7f3b5ca206a943c3be90fd79c3db57dfb7fddad066d`. This proves a key-construction defect; it does not justify replacing the expected digest or relaxing the input guard.

Use the directory enumerator's actual relative pathname contract rather than character offsets between differently represented URL aliases. Keep regular-file/symlink/size/count guards, sorted-key encoding, payload hashing and all continuation behavior unchanged.
