<!-- markdownlint-disable MD013 -->
# chore(diagnostics): pin the current front-visibility failure image

This unmerged branch reuses the held retained-image LLDB entrypoint for source52ce and failed run39839922136. It pins image SHA256 6bf5c2489a14563ee3040df141ff957677f6e8520f2c82fec4ad22830d60efeb, UUID E97D806C-28C7-32C9-A102-313DC07DEE89 and original 344-method selector hash bc897adf7c0d8d82ff54d92b855a8b43dd40de2b13633a0838c82a06896f19b4. Source/resources/helper arguments and installed runtime dependency closure must match before launch.

One retained executable launch captures the first actual stop, all-thread frames and PC/LR/SP/FP/general registers. The existing stop/output/owned cleanup guards remain, with the deadline reduced to180seconds. No build or test/source/state mutation occurs. If there is no attributed fault or a prerequisite fails, stop and report the limit; no second launch is authorised.

The delta from52ce is only the manual diagnostic workflow, existing replay entrypoint and these paired notes. Production, tests, selector and shared capture tooling are exact52ce. Syntax, immutable pins, filter/helper metadata and four-path scope are checked before dispatch. Actual capture outcome is recorded separately. Never merge this diagnostic branch or count it as unit/full-quality acceptance.
