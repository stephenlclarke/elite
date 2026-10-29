# Shut down native audio at the real window close boundary

## Change

The candidate starts from exact maina99dafbf and preserves the reviewed Lua non-returning declaration. AudioPresenter gains a terminal, idempotent main-actor shutdown. It marks itself closed before stopping the cutter, owned players and speech, then clears playback ownership. update and private play reject later work. AppDelegate.windowWillClose invokes that shutdown; applicationWillTerminate already calls this same close path. A frame suspended in actor work may finish its existing work but cannot restart the closed audio owner.

Normal active-window playback, volume, source synthesis, speech preferences and isPlaying pruning remain unchanged. Shutdown uses native stop calls independently of completion delegates, so it does not depend on a normal finish callback after interruption, decode error or explicit stop. Failed play still follows the existing refusal path. No delayed release, global retention, callback framework, muted output or new public API is added. The internal players array becomes externally read-only within the module so native tests can hold actual player objects and verify that shutdown stops them, rather than merely clearing an array.

## Meaningful native regressions

Three new methods join the existing serialized NativeViewTests cohort. They use genuine generated-effect AVAudioPlayer playback with its normal volume and require active playback before asserting shutdown:

- nativeAudioShutdownStopsOwnedPlaybackAndRejectsLaterUpdates verifies actual player stop, repeated shutdown, later dock/flight updates remaining closed, and a separate active presenter still playing normally.
- nativeWindowCloseDuringFramePreventsAudioRestart calls actual NSWindow.close inside the real processFrame delta callback immediately before actor advance. It verifies active playback at close, a stopped retained player, and no restart when that frame and another actual frame finish.
- nativeApplicationTerminationStopsAudioAndIsIdempotent exercises the existing applicationWillTerminate callback, repeated shutdown and a later update.

StartupSaveRegistrationTests' manually owned recovery/flight window now invokes the actual close producer in defer. NativeViewTests' existing frame/menu/focus fixture also closes in defer on early failure, retaining its original close and loop assertions. All existing startup/save/ownership/gameplay assertions are unchanged. G4's finite exact-a99 audit found six methods/seven parameter cases across eleven processFrame call sites. Existing EMP and three work-guidance fixtures already close through the real producer; the two cleanup changes above cover its remaining gaps. No additional playback owner was found in that traced inventory. This is source inventory evidence, not a claim to identify the crashed test.

## Validation and remaining limits

Strict formatting and whitespace checks pass. The three new native methods and affected fixture methods are UNRUN; exact-source independent review and actual focused/required validation are pending. No compiler, native test, GUI, probe, sanitizer or media run occurs during authoring. The concrete close/playback admission defect is corrected in source; the association with the previous signal11 remains an inference. Native stop is not claimed to drain private finishedPlaying callbacks or cure that crash. Full final-head checks, ordinary protected merge, fresh main Sonar and the usable signed/notarized release remain required. See [the issue](ISSUE-m01-audio-close-lifecycle.md).
