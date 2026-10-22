<!-- markdownlint-disable MD013 -->
# chore(diagnostics): pin the current front-visibility failure image

This unmerged branch reuses the held retained-image LLDB entrypoint for sourceeed9 and failed run39845001834. It pins image SHA256 9081c826d5dc55d78dc649e8b99d3400ffb10406c1db1342f85cc3fce0785059, UUID B50DBAA9-2482-375C-8867-1037424B648B and original 346-method selector hash 48afd0a198777bcaed1a18350fde67792d5f835d25c33ec1fb2e3c1fc469dd6e. Source/resources/helper arguments and installed runtime dependency closure must match before launch.

One retained executable launch captures the first actual stop, all-thread frames and PC/LR/SP/FP/general registers. The existing stop/output/owned cleanup guards remain, with the deadline reduced to180seconds. No build or test/source/state mutation occurs. If there is no attributed fault or a prerequisite fails, stop and report the limit; no second launch is authorised.

The delta fromeed9 is only the manual diagnostic workflow, existing replay entrypoint and these paired notes. Production, tests, selector and shared capture tooling are exacteed9. Syntax, immutable pins, filter/helper metadata and four-path scope are checked before dispatch. Actual capture outcome is recorded separately. Never merge this diagnostic branch or count it as unit/full-quality acceptance.
