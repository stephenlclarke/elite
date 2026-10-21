# Elite-A special cargo generator

G04 uses pinned S45 elite-source-docked.asm, cour_buy/cour_start/cour_count/cour_dock, from [Elite-A source](https://github.com/markmoxon/elite-a-source-code-bbc-micro/blob/75433e92e4914f970b14132fce6c8da68da5692f/1-source-files/main-sources/elite-source-docked.asm). [Source arithmetic fixtures](data/elite-a-courier-fixtures.json) compare the source instruction control flow with an independent translation for1,024 deterministic menu inputs. The source LL5 integer square root was also checked exhaustively for all65,536 inputs. UI/printing subroutines are stubbed, TT20 and unsigned squaring are explicitly modelled; this is a selected generator core check, not a retail executable/UI parity claim.

## Inputs, seed and selection

Reject opening new offers if the current 16-bit courier reward is nonzero. The current station visit supplies market random byte QQ26, system x/y bytes QQ0/QQ1, legal byte FIST, combat-score low byte TALLY, galaxy index GCNT, Elite-A ship index cmdr_type and previous courier destination x/y bytes. The ship index depends on the selected released/source-disc ordering; do not substitute the canonical ship ID. Previous destination coordinates persist after payment and affect subsequent menus.

All A-register operations below wrap to eight bits and retain carry exactly as indicated. ADC(a,b,c) returns byte(a+b+c) and carry(a+b+c>255). SBC(a,b,c) returns byte(a-b-(1-c)) and carry(a-b-(1-c)>=0).

1. Initial skip = marketRandom XOR currentX XOR currentY XOR legal XOR combatLow.
2. Set carry1. ADC(legal,galaxy,carry), then ADC(result,shipIndex,carry). Store this byte as subsequentSkip.
3. ADC(result,initialSkip,carry), SBC(result,previousDestinationX,carry), SBC(result,previousDestinationY,carry). Maximum offers = result AND15. Zero means no offers.
4. Reset galaxy system seeds to system0. Standard Galaxy1 words are 0x5A4A,0x0248,0xB753; rotate each seed byte left by galaxy index, wrapping eight bits, for the corresponding classic galaxy.
5. For each offer, advance by skip systems, where byte skip0 means256 advances. Each system advance twists the three16-bit words four times: [s0,s1,s2] becomes [s1,s2,(s0+s1+s2) AND65535] per twist. Increment a byte system counter on every system advance; wrapping to0 ends generation immediately before considering that system.
6. Current candidate x=s1 high byte, y=s0 high byte. If both match the origin coordinates, skip it. After considering a candidate, set skip=subsequentSkip and continue until maximum offers or the system-counter wrap. The source never offers system0 through this scan and performs no route-reachability or seven-LY destination restriction.

Menus remain stable while those inputs remain stable. Acceptance/docking/market state can change inputs; do not replace this generator with a fresh RNG every time its menu opens.

## Legality, fee and reward

For the candidate, let z=s2 high byte. Proposed legal increment is x XOR z XOR subsequentSkip; keep it only when it is strictly less than the commander's current legal byte, otherwise use0. Thus a Clean commander receives only zero-increment offers in this source.

Compute dx=abs(candidateX-currentX), dy=floor(abs(candidateY-currentY)/2). Q=floor(sqrt((dx*dx+dy*dy) AND65535)). The16-bit wrap before square root matters for large displacements; do not silently use an unbounded Euclidean result. This is raw coordinate distance, not an already scaled light-year quantity.

Set high = max(Q,(candidateY XOR z XOR subsequentSkip)>>3) bitwise-OR legalIncrement. feeRaw=floor(high*257/8). rewardRaw=(high<<8) OR (feeRaw AND255). Fee and reward share their low byte in the original menu tables. Both are **decicredits**; display/divide by10 only at the boundary to common-project credit units. Preserve exact integer money internally.

Acceptance requires enough cash for feeRaw and subtracts it atomically. Store candidate x/y and rewardRaw, and set legalStatus=(legalStatus+legalIncrement) AND255. Do not saturate the historical byte or invent a commodity quantity/ordinary hold-space check: this source represents special cargo through courier fields, not a counted market commodity. A separately designed project cargo adapter must label any additional capacity requirement.

## Docking and persistence

Every docking callback with nonzero reward compares current x/y with the stored destination coordinates. A match pays the raw reward through MCASH, then zeroes both reward bytes; repeat docking cannot pay again. Any other docking shifts the16-bit reward right by one. When that reaches zero the obligation ends without payment. Hyperspace, elapsed time and flight distance alone do not reduce it. A coordinate match, rather than an independently stored system ID, is the original completion predicate.

The stay_here routine also invokes cour_dock while refreshing the market; record this extra source trigger so a station-services refresh is not mistaken for harmless menu viewing. A common project profile may restrict penalties to actual docking, but must label that repair rather than claim exact source behaviour. Source success adds a1.92-second presentation delay, not an assignment deadline.

Persist original market/legal/combat/ship/galaxy inputs for an open offer set; accepted destination coordinates, rewardRaw, cash transaction ID and last processed docking event. The selected source profile's own commander fields are authoritative. Hull switching in the project preserves accepted courier progress and does not retroactively recalculate fee/reward from the new ship index. Save migration must distinguish historical decicredits from common credits.

Verify zero skip, zero maximum, system-counter wrap, same-coordinate candidates, legal/carry/borrow wrapping, released/source-disc ship indices, distance-sum overflow, insufficient cash, Back, exact fee, repeated/intermediate/destination docking, stay_here refresh, reward1 exhaustion and hull/reload persistence. The fixtures include16 full sample menus and reward boundaries1,2,255,256,65535, alongside the wider instruction/translation comparison.
