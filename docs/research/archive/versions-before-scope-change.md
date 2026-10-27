# Archived: versions.md before mission scope change

**Excluded reference snapshot. Do not implement removed mission content from this document. The active [scope](../implementation-scope.md) takes precedence.**

## Elite versions and platform profiles

Use these identifiers in all catalogues. Dates are release-family dates; regional releases and rereleases can differ. Sources: [S01, S02, S03, S11, S13](../sources.md).

| ID | Version and platform | Differences relevant to reproduction |
| --- | --- | --- |
| BBC-TAPE | BBC Micro cassette, 1984 | Small ship set; no scripted missions; no mining or military lasers. |
| BBC-DISC | BBC Micro disc, 1984 | Expanded ships, mining, military lasers, two missions, docking autopilot and system search; loading between flight and station. |
| BBC-SP | BBC with 6502 Second Processor, 1985 | More colour and nearby ships, Cougar and rock hermits; two missions. |
| BBC-EXEC | Executive Second Processor variant | Unpublished special variant; commander and presentation changes. Do not assume additional scripted missions. |
| BBC-PROTOTYPE | Unpublished BBC Elite II material | Historical prototype ship designs; not Frontier: Elite II. |
| BBC-MASTER | BBC Master, 1986 | Reduced flicker, colour, enhanced sounds and weighted combat points; two missions. |
| BBC-COMPACT | Master Compact, 1987 | Master game adapted for digital joystick and ADFS. |
| ELECTRON | Acorn Electron cassette, 1984 | Monochrome; no Thargoids, suns, sun scooping or missions. |
| C64 | Commodore 64, 1985 | Two naval missions plus Trumbles; colour, sprites and music; weighted combat points. |
| APPLE2 | Apple II, 1986 | Two naval missions, no Trumbles mission or Cougar; reduced-flicker drawing. |
| ZX48 | ZX Spectrum 48K, 1985 | Tape-side ship differences; nova and cloaking events reported. |
| ZX128 | ZX Spectrum 128K | 128K-compatible release using the 48K memory model. S42 pins its reference tape; three event triggers use low jump-byte thresholds 32/128/254 outside galaxy 1. Full mission parity remains R2. |
| CPC | Amstrad CPC, 1985 | Distinct ship selection; nova, cloak and captured-station events reported. |
| MSX-TAPE | MSX cassette, 1987 | Smaller ship set; mission inventory not separately established. |
| MSX-DISC | MSX disc, 1987 | Expanded ships and five source-mapped missions/events. S41 disk scheduler counts 64 eligible arrivals between assignments; selected rewards/cargo differ from BBC/ST. Cassette parity is not inferred. |
| EINSTEIN | Tatung Einstein, 1987 | Spectrum-related conversion; individual mission mapping unresolved. |
| PC-CGA | IBM-compatible DOS Elite, 1987 | CGA; selectable solid and wireframe implementations; three missions reported. |
| ST | Atari ST, 1988 | Solid ships; five mission graphs confirmed in the pinned original-source directory. Retail binary equivalence and enhanced revisions remain separate. S36. |
| AMIGA | Amiga, 1988 | Solid ships and Amiga audio; five missions/events reported. |
| ARC | Archimedes Elite, RISC OS, 1991 | Independent NPC activity and four distinct story missions. |
| ARC-GOLD | Archimedes Elite Gold | Packaging/reference-material edition; no established new mission set. |
| PC-PLUS | DOS Elite Plus, 1991 | EGA/VGA/MCGA and seven reported special events; not the BBC mission script. |
| PC98 | NEC PC-98 Elite Plus, 1992 | Japanese conversion; mission-by-mission parity remains unverified. |
| NES | PAL Nintendo NES, commercial release 1992 | Controller interface; three missions including Little Squeakys; NTSC variant exists. |
| ELITE-A | Angus Duggan's BBC extension | Buy different ships, special cargo deliveries, encyclopedia; original naval logic requires its own check. |
| PLUS4 | Unofficial Commodore Plus/4 conversion | C64-related; individual mission parity not established. |
| TNK | Elite: The New Kind | BBC-derived recreation; Windows and community ports to Linux, macOS, BSD, BeOS, Atari ST and handhelds. |
| GBA-TNK | Game Boy Advance New Kind | Different controls; C01/C02 and repeatable C08 confirmed in S37. Thirty-asteroid quota and 6,000-credit payout; initial destination has a source initializer defect. See classic port profiles. |
| GBA-AGB | Elite AGB | Separate related homebrew edition; do not equate it with GBA-TNK. |
| ORIC1337 | Oric 1337 | Independent fan reinterpretation with Microdisc support; twelve story assignments including C01/C02, plus four tutorials, confirmed in S38. See Oric campaign specification. |
| OOLITE | Oolite base game | Five built-in mission/event families plus generated contracts. |
| OOLITE-OXP | Oolite expansions | Each pack is a separate optional profile; compatibility differs by release. |
| FE2 | Frontier: Elite II, DOS/Amiga/ST, 1993 | Newtonian flight, complete systems and planetary landings; generated civilian and military missions. |
| FFE | Frontier: First Encounters, DOS, 1995 | Frontier mechanics plus dated story missions, special ships and unfinished branches. |
| ED-LEGACY | Elite Dangerous legacy branch | Older PC/console content; do not attach newer Live ships or Operations. |
| ED-LIVE | Elite Dangerous Live, Windows | Continuing content, generated ship missions and research assignments. |
| ED-ODYSSEY | Elite Dangerous Live with Odyssey | On-foot objectives and Operations; Horizons is part of the base game. |
| ED-ANNOUNCED | Announced Elite Dangerous content | Known names whose released availability is not confirmed by this research. |

## Original releases and revisions

BBC disc launch binaries have refund and asteroid bugs fixed in a subsequent release. SNG47 bundles existing BBC disc, Second Processor and Master variants; it is not an additional mission campaign. The Compact adapts controls and storage. Source-disc builds and Executive builds can differ from commercial binaries. [S02](../sources.md)

Modern BBC enhancements include flicker-free Elite, Teletext Elite, two-player combat, the Universe Editor, Econet support and Compendium collections. Amiga Advanced and later ST/Amiga community enhancements are separate modifications. Their names alone do not establish new missions. [S27, S31](../sources.md)

## Corrections to the conversation

- PC-CGA supports selectable solid and wireframe modes.
- APPLE2 has two missions; obsolete FAQs suggesting Trumbles are superseded by the code-based comparison.
- The presence of a cloaked Cougar in BBC-MASTER is not a separately scripted cloaking-device mission.
- ARC uses its own four missions; it must not inherit the BBC naval campaign by assumption.
- Eagle Mk II names and Sidewinder aliases can be grouped for a name catalogue while still requiring different geometry and physics profiles.
- Earlier lists omitted the Frontier Lifter, Lion and Spar and did not establish all spacecraft appearances. The saved catalogues include these and preserve uncertainty.
