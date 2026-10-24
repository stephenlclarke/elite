# Script cash tests must state their balance baseline

Observed CI955 failures in the five assigned script/mission test files assume a 1000-credit-unit starting balance while the current starter has 7200. Rewards, deposits, timer cancellation and no-payment rules remain authored independently of that starter balance. The campaign retry fixture also intentionally faults below 2000; the new default no longer reaches that negative branch. No production economic defect is established.

Root assigns MC1 ScriptCampaignGalleryTests.swift, ScriptWorldJobTests.swift, ScriptEventHistoryTests.swift, EMPArchiveStackTests.swift and MissionPackTests.swift, with these paired notes only, isolated on committed `ee6ca715130ecf12334066e40e1da4a018ab1b8a` (a current canonical 908f descendant). Capture pre-action balances where the test is about a deposit, a 25-unit timer payment or zero income. Set explicit1000 only for the intended low-capital fault and four observed classic courier balance scenarios.

Preserve every authored reward/deposit, exact identity, custody, rollback, once-only and timing oracle. The actual trial runtime supplies the world-job baseline; its parent commander does not. Source-only validation remains pending: ten methods/thirteen cases through G1, with no previous PASS retained for changed consumers. The existing naval freeze is untouched.
