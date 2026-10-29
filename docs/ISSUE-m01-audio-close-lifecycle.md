# Stop native audio when its window owner closes

## Proven defect

At exact maina99dafbf, AppDelegate.windowWillClose cancels its loop but does not shut down GameView.audio. An already-entered processFrame can resume from actor calls and unconditionally call audio.update after close. A retained closed view can therefore start or retain sound effects, the cutter or speech without an active owner loop. This lifecycle and ordering defect is established from the actual production source, independently of crash attribution.

## Existing failure evidence and limits

Main run40951152504 attempt2 passed its first3403-case normal phase with90.493764416% coverage and a fresh zero-leak check. Its second normal phase crashed with signal11 after1482 seconds, before Sonar upload. The retained macOS report matches the failed image UUID and shows queued main-thread Objective-C dispatch involving finishedPlaying. Existing OS logs show generated-effect-compatible audio queues stopping/deleting just before the crash. Those facts support an audio-lifetime lead but do not prove the dead receiver, responsible test or that shutdown drains private callbacks. No retry, profiling or heuristic delay is evidence of a fix.

## Required behavior

Closing the real window or terminating the application must stop its owned audio once and reject future playback, including a frame already in flight. Preserve active-window playback, existing isPlaying pruning, source audio synthesis, native assertions and actor isolation. Use genuine playback regressions and faithful fixture cleanup. No muting, mocked-away playback, skipped checks, indefinite retention, allocator or playback framework. See [the change](PR-m01-audio-close-lifecycle.md).
