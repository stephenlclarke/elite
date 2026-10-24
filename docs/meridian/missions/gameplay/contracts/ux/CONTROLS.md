# L337 shared controls and help

Private proposal controls and help copy; game implementation and handoff are not authorised.

## Flight controls

| Key | Action |
| --- | --- |
| **W** | Change weapon |
| **Return** | Fire |
| **E** | ECM |
| **Q** | Release hold |

Flight controls. Every help screen includes this same clearly labelled Flight controls block. Menu and mission-dialog confirmation remains a separate context; Return in a menu confirms its focused choice and never fires a weapon.

**W - Change weapon.** Cycle equipped Main Laser, Mining Laser, Salvage Cutter and EMP Blaster. Update the persistent weapon indicator immediately; retain the current hold.

**Return - Fire.** Hold Return to operate the selected weapon: fire the Main Laser, mine with the Mining Laser, cut with the Salvage Cutter, or charge/fire EMP. Release to stop the held action. Require a fresh press after a weapon change, readiness transition or interruption. Releasing Return retains the hold.

**E - ECM.** Activate fitted ECM directly, subject to actual energy and cooldown requirements. ECM stays separate from weapon selection.

**Q - Release hold.** End automatic hold/guidance and stop the active tool. Return control to the player while preserving momentum.

Targeting any disabled ship for salvage selects fitted Salvage Cutter immediately. Targeting an asteroid selects fitted Mining Laser immediately. Selection never fires. W overrides the default for the current target without releasing hold.

The persistent WEAPON indicator shows the selected fitting and its actual state. The common footer is `W: CHANGE WEAPON | RETURN: FIRE | E: ECM | Q: RELEASE HOLD`.

## Asteroid targeting and destruction

Asteroid targeting establishes a safe target-relative hold and selects the fitted Mining Laser. W can select Main Laser instead; held Return then breaks the rock into much smaller chunks, leaving strictly less than 5% of its original mass recoverable. Most rock disintegrates permanently. Collect surviving chunks with fitted scoops; changing weapon or firing does not release the hold before the parent breaks apart.

[Help-screen copy](https://github.com/stephenlclarke/elite/tree/6552b68f7a146ceb79b4376d33cc8afd3f987399) / [Control definition](controls.json) / [Salvage and mining design](https://github.com/stephenlclarke/elite/tree/6552b68f7a146ceb79b4376d33cc8afd3f987399).

## Help-screen consistency

- Generate README controls, help-screen flight blocks, contextual footers and the salvage guide labels from these four bindings. No help topic may assign another key to these actions.
- Keep the primary Return action label Fire for every weapon. Mining, cutting and EMP charging are explained beneath it and in the actual weapon/activity indicator, not by changing the binding label.
- All flight views and help topics use Change weapon rather than alternating between Change tool and Change weapon; Q is Release hold rather than Off, Back or Cancel.
- Equipment prerequisites and temporarily blocked states are explained alongside the binding without remapping its key. Menu navigation and confirmation are clearly distinguished from Flight controls.
- The game implementation must consume the shared control authority for every help topic and visible action hint, with regression coverage that enumerates all actual help screens. Generated proposal previews are design copy, not a claim that game UI has been updated.
