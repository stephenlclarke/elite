# Preserve station-token grammar without per-byte arrays

Native station identities are revalidated during real flight. The UTF-8 token check now uses an explicit ASCII switch instead of a closure containing a temporary punctuation array. Empty/over-80-byte tokens, non-ASCII text and unsupported local system identities still fail. A syntactically valid alias still cannot obtain canonical source authority.

The new regression covers the 256 Latin-1 scalar inputs, the allowed alphabet, exact byte limits, control/separator and multibyte Unicode rejection, real canonical binding, a valid-looking alias and the unchanged RRS local system boundary. No validity cache, skipped check, history eviction or authority relaxation is introduced.

Source formatting and review precede execution. The matching post-change native-validator/world benchmark, coherent affected tests, full CI and native gameplay performance checks remain pending. The baseline helper's compiled-source identity is distinct from its already-composed checkout; its timings do not establish new-feature acceptance or native frame pacing.
