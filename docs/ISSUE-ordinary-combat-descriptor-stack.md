# Ordinary EMP combat enters an unnecessary mission descriptor frame

Full `make ci` attempt 331 at `14899e22a04789fe280f69e54987be80b8c06011` stopped during coverage with another authenticated thread-stack exhaustion crash. This path starts in the genuine EMP/people persistence fixture and reaches retained mission descriptor construction through electrical pulse combat attribution. The ordinary target has neither mission ownership tag; the existing retained factory necessarily returns nil, but its heavy frame and four caller Commander reads were entered first.

The exact coverage executable `955f50d5beeedd2b0d65f9f913712295572f22b9a4e6096fe11d4cf817b29270`, all 715 objects and owned-process crash are preserved in `/tmp/elite-full-review-ci-331`. This executable is byte-identical to passing focused validation 329, whose event-admission regression remains separately qualified. The new crash is a different source path. Attempt 331 did not finish coverage or reach threading, address-sanitizer or leak acceptance.

Reject ordinary bodies before allocating mission source/validation frames. Genuine mission bodies must still pass the unchanged complete retained owner, encounter, fit, geometry and native binding census. Keep Blackjack/naval and ordinary crime/reward fallthrough intact. Avoid whole Commander temporaries when collecting the same immutable source fields; do not add an owner, cache, box, stack override or budget waiver. Existing exact-crash, genuine scripted bounty, projection/forgery, ordinary EMP and original mission reward tests supply the affected regression selection.

[PR-ordinary-combat-descriptor-stack.md](PR-ordinary-combat-descriptor-stack.md).
