# Native startup frame cost cannot be observed through the planet-only entry point

F01's reviewed startup source passes ten focused debug/coverage methods, but the 120-frame title/credits unit took 50.178 seconds. That is not an optimized native-window frame measurement. The attempted Release test-target build timed out before an optimized test or native observation began. There is no measured startup FPS or frame-budget acceptance.

GameView.draw already clocks Display.presentation and drawFrame when its existing PlanetFrameProfiler observer is present. The only existing CLI setup configures a planet flight: warm a window, launch, hold throttle, and measure a flyby. Reusing that setup as a title test would measure a different scene and input path.

Add a bounded title/credits entry to the existing observer and application loop. Keep the renderer, original SH123 geometry, normal app behavior and planet flight protocol unchanged. Record actual visible-window draws with truthful scenario/source/binary identity, stop after a finite number of distinct draws, and refuse an incomplete or changed scene. No new profiler framework, generated image, optimization or frame-rate claim is part of this change. Related implementation note: PR-startup-native-frame-observation.md.
