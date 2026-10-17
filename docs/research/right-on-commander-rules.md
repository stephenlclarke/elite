# Right on, Commander: verified award rules

This is a combat-progress message, not a mission payment or equipment award. Keep it separate from cash bounties, mission rewards, rank promotions and the Constrictor offer. Edition rules differ; selecting a common phrase does not establish a common counter.

## Original BBC Micro and Elite-A

The [original BBC Micro EXNO2 routine](https://elite.bbcelite.com/cassette/main/subroutine/exno2.html) increments the low byte of the saved kill tally, and only when that byte wraps from255to0 increments its high byte and displays text token101. Thus the first message is at256 credited kills, then512,768,1024 and every subsequent256. It continues beyond Elite's6400 threshold. It does not require docking, clean legal status, hostile/pirate targets, a mission, a particular galaxy or a rank change. EXNO2 itself changes no credits or equipment; separate destruction/bounty code may do so.

The recovered Elite-A source has the same EXNO2 behaviour in elite-source-flight.asm lines28954 onward, pinned S45 commit75433e92e4914f970b14132fce6c8da68da5692f. [Source](https://github.com/markmoxon/elite-a-source-code-bbc-micro/blob/75433e92e4914f970b14132fce6c8da68da5692f/1-source-files/main-sources/elite-source-flight.asm). Only credited events that call this routine count; it is not an award for256successful missions,256credits earned or256minutes played. A mission's direct tally adjustment is a separate code path, not automatically a fresh kill event.

Original storage is16-bit, so it can wrap at65536; the routine also emits on that overflow. Project adaptation uses a persistent non-wrapping commander kill counter and emits at each positive multiple256, avoiding loss of rank/progress at legacy overflow. This is an explicit project repair, not an original storage claim. At255kills no message; next credited kill→256/message;257none;511none;512message;6399none;6400message plus separate Elite rank update;6656message. Loading an existing tally or switching ships must not award it again.

## Oolite

Pinned O08 PlayerEntity.m collectBountyFor at lines6049..6097 establishes the native rule: after an eligible destruction, increment ship_kills; if ship_kills%256==0 queue right-on-commander after0.2seconds with forCount4. This is immediate in-flight feedback, not a station claim. [Pinned source](https://github.com/OoliteProject/oolite/blob/574ca848c91a067178416216523e8d09c1e9282a/src/Core/Entities/PlayerEntity.m#L6049).

Eligibility in this code excludes a dead player, null target, subentity, main station and a currently cloaked player. counts_as_kill defaults true through ShipEntity.countsAsKill but a ship definition can disable it. Cargo carrying a commodity and not a hulk, buoys and rocks give no kill unless the special tharglet role applies. Destroying police can count while also increasing legal status; a clean commander or positive bounty is not required. Bounty payment is separate and a zero-bounty qualifying ship can count. The message itself supplies neither cash nor equipment. [Native countsAsKill default](https://github.com/OoliteProject/oolite/blob/574ca848c91a067178416216523e8d09c1e9282a/src/Core/Entities/ShipEntity.m#L1527).

Do not infer that every object's removal, every scripted NPC death, every destroyed component or every direct player.score assignment runs collectBountyFor. Mission score corrections and source fixture deaths must be kept separate from the project's commander kill event. NPC killer/player ownership attribution must follow the selected weapon/engine source path.

## Other recovered port distinctions

| Edition/profile | Verified trigger | Evidence and limitation |
| --- | --- | --- |
| C64 | Carry from fractional+integer weighted combat tally into its high byte, crossing a256point boundary; not necessarily exactly256destroyed craft or a final tally divisible by256. | S34 elite-source.asm EXNO2 lines43052 onward; KWL/KWH ship-weight lookup. |
| NES | Same high-byte carry after IncreaseTally adds doubled source fractional/integer ship weights. | S35 bank0 EXNO2 line24105 and bank7 IncreaseTally line13116. Tables and difficulty remain edition-specific. |
| Oric1337 | ShipKillValue added to fractional score remainder/integer score; carry increments score high byte and pending righton. | S38 tactics.s lines2085..2099. tineloop.s checks pending notice in32frame periodic work, after low-energy warning priority; clears pending count and displays once. Multiple pending crossings can coalesce. |
| Atari ST recovered source | Rank promotion immediately shows the same text. Otherwise increments one8-bit kill subcounter and shows on wrap; promotion events skip that increment. After Elite it keeps checking the subcounter. | S36 combat.m68 add_kill lines335..363, text5 at1838. Weighted rank score and announcement subcounter are different. |
| MSX recovered source | Weighted score reaching the next rank threshold increments rank and shows the text. Otherwise increments COMBAT_KILL_COUNTER and shows when it wraps. Promotion does not increment the subcounter. | S41 code.asm ADD_COMBAT_SCORE addresses32E7..3323, lines6869..6905. The recovered literal is Right On Commander, even though some secondary accounts call promotion messages Well Done. |
| GBA NewKind1.7.1 source | explode_object increments commander.score by1, then score&255==0 shows the text. | S37 swat.c lines77..81. This describes the selected source path, not proof of every retail ROM destruction attribution. |

The [combat-rank analysis](https://elite.bbcelite.com/deep_dives/combat_rank.html) explains the BBC and weighted6502 progression; the recovered source routines above are authoritative for the listed profiles. C64/NES/Oric crossing checks must not be replaced with integer modulo when a weighted kill can skip an exact multiple. Master/AppleII use weighted6502 progression per that analysis, but their individual source callbacks were not newly executed here.

Archimedes secondary FAQ reports Good Shooting every50kills and Right On at249,499,749,...; preserve this as reported edition behaviour, not a primary-source-verified project default. [FAQ9](https://wiki.alioth.net/index.php/AFE_FAQ9). Elite Dangerous uses the phrase in Elite-rank congratulation correspondence; there is no established every256kills Dangerous rule in this research. Frontier missions remain outside active scope, and no Frontier award rule is inferred from conflicting forum recollections.

## Project implementation contract

Use the BBC rule for the common original-Elite project profile unless another explicit edition is selected. GameRuntime owns commander-wide credited kills, rank, last emitted milestone/event and award generation. On a unique qualifying kill, update the saved tally and enqueue one short in-flight notification when a new positive256milestone is reached. No money, equipment, docking action or mission completion is attached. Respect selected mission/NPC kill-credit exclusions; never count detachable components, despawn/reload, scripted replacements or repeated death callbacks twice. Equipment/ship transfers preserve commander progress and pending notification identity.

For weighted editions compare old/new tally boundary indices, retaining fractional precision. For ST/MSX retain their separate promotion and non-promotion subcounter behaviour. Save before acknowledging a notification so reload cannot replay an already shown event. A user loading a commander already at256does not receive a new message merely for loading. Verify255→256,256→257,511→512,6400andbeyond, zero-bounty qualifying target, excluded object, player/NPC attribution, weighted255.8→257.1, promotion/subcounter divergence, save/reload and hull switching. Exact UI queue/display duration is a project choice unless an explicit edition duration is selected.
