<!-- markdownlint-disable MD013 -->
# Diagnostic-only retained-image capture for #106

The current source eed9dae5b7a1fae098a85a57a996d555f55f3b2b compiled in run 39845001834, then isolated execution ended with signal4, zero completed PASS methods, no matched crash report and invalid 52-byte XML. Its arm64 image and matching dSYM have UUID B50DBAA9-2482-375C-8867-1037424B648B. Current compiled inspection confirms the renderer-owned Game copies are gone and the recorder wrapper uses a128-byte fixed frame with its full validation behind the marker. No current fault frame was retained, so another product correction is not justified.

Root approved one retained-binary launch using the existing held diagnostic entrypoint, original 346-method selector, jobs3, coverage instrumentation, runtime closure and resource bytes. Pin source, upstream run, image SHA and UUID, symbols and filter. Stop before launch on any prerequisite mismatch. Capture the first actual fault with all-thread frames and registers, then clean up the owned process. The limit is 180 seconds and there is no retry or rebuild. Diagnostic evidence is not qualification.

This branch must never merge. The previous a561/392e captures remain historical evidence; they do not attribute the current failure. No source, test, oracle, save, state, stack-size or shared crash-capture authority change is part of this packet.
