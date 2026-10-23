# PLUGH shop research prerequisite fixture correction

The same retained f6 quality39983992820 reports the generic PLUGH shop test's
availability, cash and receipt expectations failing specifically for Alien
Seeker Missile, with the actual message NOT AVAILABLE. The generic fixture has
no alien missile research, while production explicitly requires that real
native research plus the actual fitting service. The discount itself matches.
This is distinct test issue148, not a production pricing or research-gate bug.

The generic shop case now checks the locked item's proper discount and actual
refusal, with unchanged cash/fuel/paid count and no minted alien item. All other
stock, purchase, mount and reward assertions remain. The existing researched
PLUGH supply case obtains genuine research through its original fixture and
now also checks the exact450CR paid receipt/node and one receipt increment.
Its original stock, pylon, prototype, duplicate-refusal and flight restrictions
remain. No fake eligibility flag, duplicated journey fixture or production
gate change is introduced.

The two existing methods share one focused build with147's four methods.
Execution is pending. This is not a full524, quality, native M01 or release
qualification, and no cause is inferred for unrelated VM signal144.
