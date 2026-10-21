# Programmatic windows need explicit ARC ownership on close

## Problem

The application window and the commander-file test fixture construct `NSWindow` directly, retain it through Swift properties, and do not use `NSWindowController`. Neither constructor disabled AppKit's automatic release-on-close behavior. Apple documents that Swift and ARC clients must disable this behavior to prevent an extra release: [isReleasedWhenClosed](https://developer.apple.com/documentation/appkit/nswindow/isreleasedwhenclosed). The [close() contract](https://developer.apple.com/documentation/appkit/nswindow/close()) also explains that automatic release can occur after the current event and that closing posts the window's close notification.

## Required behavior

Set `isReleasedWhenClosed = false` immediately after each construction. Swift's explicit strong owners manage lifetime; AppKit window, delegate and view access remain on the main actor. A real application-window close must cancel the frame loop through the existing delegate callback. Its task must join, and retained owners must remain usable after a subsequent main-run-loop callback. The commander-file fixture must enforce the same policy without changing file-operation rollback or cleanup behavior.

## Evidence and scope

The current SDK declares `releasedWhenClosed` with the `isReleasedWhenClosed` getter in `AppKit.framework/Headers/NSWindow.h`. The defect follows from the constructors and Apple's ownership contract. The hosted Thread Sanitizer trace contains Objective-C/Foundation/run-loop frames, but does not identify a project allocation, release or data race. This ownership fix has not been established as that crash's cause or repair.

## Acceptance

Both constructor policies are checked by native regressions. The application test closes the actual window, observes cancellation, awaits the actual loop and a main-run-loop callback, then reads and writes the retained window. The fixture test closes its actual window and accesses the strong fixture owner after a run-loop callback. Existing commander rollback and teardown tests remain intact. No sleep, timeout increase, zombie mode or global retained-window workaround is introduced.

Compilation, execution, sanitizer and leak validation require the coordinator's next validation lease. At this source checkpoint the new regressions are uncompiled and unexecuted. See [the implementation handoff](PR-native-window-arc-ownership.md).
