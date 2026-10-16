# CR-05: Use one elapsed-time ECM clock

ECMControl owns remainingDuration. Both legacy frame adapters and player/external fields use that same clock; player ownership is a flag rather than an independent timer. The compatibility reference is 60 Hz, giving the original 32-frame field a duration of 32/60 seconds. The game loop advances that clock only by admitted flight delta, clears its activation when the field ends, and retains the existing three-second retaliation order window, which outlasts the field.

The shared Game.swift changes are isolated in a separate integration hook commit for the central owner. No ordnance resistance or activation identity policy changes. New regressions cover matched physical durations, external/legacy ownership, malformed deltas and once-only actual return fire. Existing retaliation and alien activation tests remain relevant.

Validation is pending the numbered validation lease. Source formatting and whitespace checks pass; no executed build, test, sanitizer or native result is claimed. Motivation: [issue](ISSUE-CR-05-ecm-time.md).
