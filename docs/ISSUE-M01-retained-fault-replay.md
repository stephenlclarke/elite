<!-- markdownlint-disable MD013 -->
# Diagnostic-only retained-image capture for #106

The current source 52ce90170e314c1ac070f71bf5d4d4436f8cedb1 compiled in run 39839922136, then isolated execution ended with signal4, zero completed PASS methods, no matched crash report and invalid 52-byte XML. Its arm64 image and matching dSYM have UUID E97D806C-28C7-32C9-A102-313DC07DEE89. Current compiled inspection confirms the old renderer-owned Game copies are gone; no current fault frame was retained, so another product correction is not justified.

Root approved one retained-binary launch using the existing held diagnostic entrypoint, original 344-method selector, jobs3, coverage instrumentation, runtime closure and resource bytes. Pin source, upstream run, image SHA and UUID, symbols and filter. Stop before launch on any prerequisite mismatch. Capture the first actual fault with all-thread frames and registers, then clean up the owned process. The limit is 180 seconds and there is no retry or rebuild. Diagnostic evidence is not qualification.

This branch must never merge. The previous a561/392e captures remain historical evidence; they do not attribute the current failure. No source, test, oracle, save, state, stack-size or shared crash-capture authority change is part of this packet.
