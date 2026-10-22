# The current station-unit failure lacks an attributable stack

[Issue 88](https://github.com/stephenlclarke/elite/issues/88) remains open after exact source 392e9ccaf873f8709cb7ae083dea91ac8ca8ca99 compiled in hosted run 39812579729 (751.73 seconds), then exited with signal 4 and zero completed method PASS records. Its artifact has no matching crash reports and invalid 52-byte XML. Previous a561 fault evidence does not attribute this current failure.

Earlier a561 source passed its original station regression once under local Swift 6.4.1 without coverage. The subsequent original-runtime retained-image replay captured a fault in station-state validation; the bounded 392e correction passed independent source review but has no current attributed failure stack. Neither historical result qualifies the current Swift 6.1.2 coverage-enabled 341-method run.

The current retained coverage image and matching symbols permit one configured replay without compiling product or tests. See [the diagnostic plan](PR-M01-retained-fault-replay.md). All earlier evidence is preserved. No new product fix or runtime acceptance is claimed.
