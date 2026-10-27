# Campaign child validation still reserves whole-record call storage

At `a71af8c70281a0909958c05355f147d7945a18f0`, batch 500 compiled and 501 passed nineteen methods/twenty cases. Both unchanged EMP variants passed in 502 on the normal task stack and concurrency. Retention run 503 still faulted in `campaignChildBindingsAreValid` entry, before the child loop could execute, through campaign/engine/Commander validity and the genuine mission bridge fixture. The original method remains unknown with zero issues. The proof SHA256 is `11b7ad127f7963da2a7ee252def3725baed50341ec14e482ada6b62ff2736a3b`; owned IPS SHA256 is `1df88a0eb18bdde349ca618130bdca2a68b3911fb31e72a1925b4915b478cc86`, PID 28540, in `/tmp/elite-native-journeys-focused-503`.

The child loop still takes a full parent ScriptInstance and ScriptEngineState, reserves a full child lookup and passes all three large values into binding validation. Those buffers exist even when the child dictionary is empty; splitting category lifetimes alone did not remove these argument types. Meaningful populated campaigns also need child/root/owner lookups without keeping unrelated contract, courier, payload, encounter or engine-ledger state in the validation chain.

Project only actual immutable campaign fields at read boundaries, preserving every membership/definition/time/revision/acknowledgment/duplicate predicate and full binding comparison for empty and populated collections. No empty-child bypass, authority cache, serialized field/test/actor-commit change, publication rewrite, stack increase or concurrency change is acceptable. Keep the newly passing writer/EMP encoding untouched.

[PR-campaign-validation-value-inputs.md](PR-campaign-validation-value-inputs.md).
