# Keep native Crimbo fixture mutations outside assertion expansion

The newly composed provider and lifecycle fixtures directly invoke mutating actor allocators, persistence, custody transfer acknowledgements and one-use attained-motion consumption inside Swift Testing assertion macros. Earlier native fixture compilations demonstrated that this pattern can extend mutable value access through macro diagnostics. Avoid carrying it into the next sanitizer build.

Evaluate each real mutation once into a local, then assert the same result. Preserve every call, its order, original fixture data and expected error/resource/ownership outcome. Thrown-operation assertion closures remain unchanged. This is source hygiene before compilation; no failure in this new source is claimed.

[PR-native-crimbo-macro-inputs.md](PR-native-crimbo-macro-inputs.md).
