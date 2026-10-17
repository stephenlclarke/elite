# Player control guide

The main pattern is the same everywhere: **numbers open areas, arrows move, Return chooses, Escape goes back one level, K opens contextual help**. Visible buttons and the Mac menu bar expose secondary actions. Search receives ordinary typing until Return or Escape finishes it; letters and numbers typed there never open screens, activate XYZZY or change galaxies.

## Main screens

| Key | Docked | In flight |
| --- | --- | --- |
| 0 | Launch | Front view |
| 1 | — | Rear view |
| 2 | — | Left view |
| 3 | Equipment | Right view |
| 4 | Galactic chart, planet facts and globe | Galactic chart |
| 5 | Short range chart, planet facts and globe | Short range chart |
| 6 | Ship showroom | System data and globe |
| 7 | Market: buy and sell | Market prices |
| 8 | Commander status | Commander status |
| 9 | Inventory | Inventory |

The Screens menu offers these same destinations. Plain numbers are the navigation shortcuts; there are no additional Command-number shortcuts. Docked 1/2 have no action; use Market (7) and Tab to choose Buy or Sell. Number keys work in read-only browsers as well as ordinary screens, but mission dialogs, help, pause and XYZZY consume their own controls. Escape from ordinary information screens returns through the screens you visited, ending at commander status when docked or your cockpit in flight. Switching to a cockpit view starts a fresh return path. Escape in the cockpit leaves you flying.

## Basic flight

| Control | Action |
| --- | --- |
| Up / Down | Pitch up / down |
| Left / Right | Roll left / right |
| Hold Space | Accelerate |
| Hold Delete | Brake; releasing holds the reached speed |
| Hold Return | Fire the laser in the current view |
| Tab | Select the next target with a fitted targeting computer; selecting the station engages full automatic docking at Docking tier or higher |
| Q | Disengage automatic guidance |
| 4 / 5, then H | Select a chart destination, then begin hyperspace in flight |

Trackpad: two fingers steer at the current speed, one brakes, three accelerate. Hold two fingers off centre to keep turning. Centre them or lift all fingers to centre the yoke and cruise. macOS gestures can intercept three-finger input; see the README trackpad section.

The yellow station compass shows range and left/right/up/down bearings relative to the current cockpit view, even beyond scanner range. BEHIND means turn toward the indicated side. It does not require equipment. To dock automatically, fit a Docking or better targeting computer and press Tab until the station is selected. Guidance faces the safe approach waypoint, stops outside the entrance, then aligns and closes through the doorway. Q or manual steering/throttle returns control to you.

## Specialist flight actions

Every action in this table is visible in the **Flight** menu. Equipment requirements and fuel, docking, mass-lock and jump rules still apply.

| Action | Shortcut, where provided |
| --- | --- |
| Next target / station automatic docking | Tab |
| Cancel guidance | Q |
| Hyperspace to selected system | H |
| In-system jump | J |
| Galactic hyperdrive | G |
| Activate ECM | E |
| Arm / disarm / fire missile | T / U / M |
| Detonate energy bomb | Flight > Detonate Energy Bomb |
| Launch escape pod | Command-Shift-E, or Flight > Launch Escape Pod |

Escape is reserved for Back. Tab selects targets and never detonates the energy bomb. I expands or collapses the target-camera panel. Option-Up/Down pages its wrapped cargo, route and resource readings. Pass scoopable cargo below your nose with Fuel Scoops fitted.

Flight HUD bearings point to the actual moving planet and sun, including astern and off-screen directions. Fuel Scoops collect solar fuel automatically when cruising nose-first in the outer corona; no extra key is needed. Stay near the corona edge, watch Cabin temp, and turn away to cool before it reaches the limit. Sun and planet surfaces are fatal, and overheating destroys the ship even with unlimited XYZZY fuel. Ordinary commander files load docked at the saved system. In the current development source, saves retain ordinary NPC identities and condition, owned equipment and accommodation, cargo custody and mission-owned actors/projectiles. Versioned mission saves additionally retain flight/world state for restoration; they do not create a fresh local scene or refill spent NPC resources. Restoration rechecks retained custody and native context. Final quality/release acceptance of the composed development changes remains pending.

Optional Spin Hold is in the Game menu. V toggles it, B stops smoothly, brackets start anticlockwise/clockwise spin, and held minus / equals or plus changes the spin rate. Arrows pitch/yaw in this mode; Space/Delete still changes forward speed. One-finger circles choose spin direction, one/two/three contacts slow/hold/increase it, and two-finger movement aims pitch/yaw. Help, pause and focus loss cancel Spin Hold. This specialist prototype is separate from ordinary flight.

## Station tasks and mission dialogs

At a main orbital station, open Market with 7. Prices, stock and your holdings stay in one table. Up/Down, scrolling or clicking selects a commodity. Tab or the visible Buy/Sell controls changes mode without changing the selected item; Return or Buy one/Sell one trades one unit. Left sells one and Right buys one. Repeat trades for multiple units. Keys 1/2 remain buy/sell mode aliases; the docked Screens menu exposes the single Market entry. In flight, 7 remains read-only prices and 1/2 remain rear/left views.

At a main orbital station, Equipment remains on 3. Up/Down selects an item and Return purchases/refuels; Left/Right or the visible mount controls chooses its laser mount. Commander Status (8) is a readiness/location/finance/legal summary. Inventory (9) owns the cargo manifest, reserved mission property and complete laser/equipment list. Up/Down or scrolling reads additional rows; Option-Up/Down pages. Escape returns to the previous area, not through each Market mode.

The development RRS waystation/headquarters docks provide **Game > Station Contracts**, with no general Market, refuelling, equipment-shop or auto-trade service. Choose and save a commander before accepting. **Up/Down** selects an assignment, **Return** opens its review, **Left/Right** chooses Confirm/Decline/Back, and **Return** or clicking selects that action. Reading or Back transfers nothing. Scenario 2 delivery requires actual entry at the same system's original main orbital station, then explicit debrief Confirm in Station Contracts. Mission Gallery reads the retained assignment without accepting or delivering it. Headquarters board access is a project extension; other RRS scenarios remain queued. See [the development delivery walkthrough](../README.md#development-rrs-document-assignments) and [current acceptance](WHOLE-APP-REMEDIATION.md).

In the current development source, **Equipment (3) > Passenger Facilities > Passenger Berth** adds cabin controls: **Return** buys/fits one, **S** stores an empty fitted cabin, and **R** refits an empty stored cabin. Each fitted cabin needs 5t and one equipment unit; the base estimated purchase price is 1,000 CR before discounts. Used/reserved cabins cannot be removed. **K** includes S/R help only for the selected Passenger Berth row. Storage/refitting keeps the owned cabin and costs no second purchase. A commander save location is required; failed saving leaves cabin state and cash unchanged. The focused native cabin methods pass; full quality/release acceptance remains pending, and this is not a claim about the published 1.4.0 app.

**Game > Mission Contacts** opens an eligible station contact. Legacy dialogs use arrows to choose Confirm or Back, Return or a click to select, and Escape to return without a transfer. Script dialogs with choices use **Up/Down** to browse answers and **Left/Right** to select Confirm or Back; **Return** or clicking Confirm submits the selected answer. Reading, changing the highlighted answer or choosing Back does not answer. Exclusive branches can be confirmed only once; repeatable conversation answers count only when the mission offers them again and you explicitly confirm each answer. **Option-Up/Down** or trackpad scrolling reads long messages. Dialogs return to the screen that opened them. These script-choice/conversation controls describe current development source; initial enrolment and automatic naval orders/rewards retain their campaign rules.

**Game > Station Rumours** opens the local station rumour. Escape returns to the previous screen. **Game > Mission Gallery** opens the mission list. **Up/Down** selects, **Return** or a click opens details, **Tab** switches list/details, and arrows/scrolling in details reads more; **Option-Up/Down** pages. **Escape** returns through campaign links/details to the list, then to the previous screen. Browsing is read-only and freezes flight.

In the current development source, **T** or **Game > Try Selected Mission** starts an eligible isolated trial. An owned campaign assignment instead opens **Try Campaign** review: arrows choose Back or Try campaign, then Return/click confirms a fresh root campaign with its assignments; Back leaves live progress untouched. **Return** in campaign details opens its links; arrows select a link and Return/click follows it. **R** or **Game > Retry Selected Mission** retries/resumes an eligible saved suspended entry after its exact required content is available; unavailable entries explain why they cannot retry.

During a trial, **Game > Restart Mission Trial** restores its authored starting state, and **Game > Return to Commander** restores the live commander and save context. Return/Space at the trial loss screen also restarts. Trial saves stay separate from the live save; a trial cannot replace live progress. These controls are source-integrated and covered by focused cases, while full composed quality/release acceptance remains pending; they are not a claim about the published 1.4.0 app.

Naval mission messages retain the two-second incoming-message delay. Return/Space advances; arrows review pages; Escape closes the message. These controls do not accept/reject a mission or change its automatic award rules. Campaign-specific details are in the campaign guides.

## Charts, search and routes

Left/Right or clicking selects a planet. Docked charts 4/5 include all planet facts, clues and the globe; Option-Up/Down scrolls that data panel. In flight, 6 retains the separate data page. The retired docked data page is replaced by showroom 6.

| Action | Control |
| --- | --- |
| Search the viewed galaxy | Slash on the galactic chart |
| Filter / select result | Type; Up/Down moves; Return chooses |
| Finish search | Escape, returning to the chart before a second Escape goes back |
| Erase / reset search | Delete / Command-Delete, or click Clear |
| Browse galaxies | Click a galaxy button, or brackets on the galactic chart |
| Current location / distance | O / D |
| Colour by economy/government/technology | M |
| Local-chart range | Z |
| Open routes with fitted navigation computer | N |
| Toggle automatic top-five profit scan | P on either chart or the navigation screen |
| Preview route candidate | Up/Down, or click a candidate |
| Commit previewed route | Return, or click Set route |
| Switch route-preview map scale | 4: galaxy / 5: local |
| Read route details | Option-Up/Down |
| Clear route | C |
| Cancel route preview, preserving active plan | Escape, or click Back |

Profit scan starts enabled by XYZZY and its switch is saved with the commander. It recomputes up to five positive-profit destinations within the current fuel and jump limit. Gold rings and numbers 1-5 highlight them on the current galaxy charts; navigation details list credit estimates or explain that none qualify. Estimates compare sellable carried cargo with selling here, then add affordable exports using available hold space and current stock, at conservative destination prices. They exclude fuel costs and danger; no cargo is bought, route selected or jump started by scanning.

N opens route alternatives with a graphical preview on either the galactic or short-range chart. Up/Down or clicking a candidate previews it without replacing the active plan. Return or **Set route** commits it; **Back** or Escape cancels the preview and preserves the active plan. Short-range legs clip to the local map, with an offscreen-continuation cue. 4/5 switches map scale while keeping the same candidates and preview.

Alternatives compare Fewest Jumps, Safest and Trade Opportunities, with a Best Cargo Sale detour when it improves estimated sale return. Identical paths combine their labels. Basic searches within installed fuel capacity in LY plus 7 LY; Advanced adds 14 LY; Military searches the whole current galaxy. Legal hops respect the fitted computer cap: the first leg uses actual remaining fuel, and later legs assume station refuelling to installed capacity. Risk and conservative trade/cargo estimates remain summaries, not guaranteed profits or affordable refuelling.

Setting a route does not jump. Successful Set route cancels any pending jump countdown before choosing the new next hop and reports that cancellation; stale candidates and Back preserve the countdown. Dock at each stop, launch, and use H for the next jump. Foreign-galaxy browsing cannot initiate actual travel or route planning.

## Ship showroom

Open with 6 while docked. W and Command-Shift-W have no showroom action. Use arrows or click to choose a ship; Return or the Specifications button reads it. Tab or the Ships/Specifications button switches the active pane, visibly named in the footer. A double-click opens specifications directly. Arrows act on the active pane; scrolling acts on the pane under the pointer. Option-Up/Down pages that pane.

Slash or clicking the search field begins a filter. Up/Down works immediately on the results, Return opens the selected specifications, Delete erases a letter, and Command-Delete clears the search. Clear filter is also clickable. No matches means no stale model. Escape leaves search, then specifications, then the showroom, preserving selection while you move between panes and help. Reopening the showroom starts unfiltered on your currently owned ship.

Click **Pin baseline**, select another ship and use **Compare**. **Your ship** restores your actual fitted ship as the comparison baseline. **Prev profile / Next profile** cycle the current source/refit set. **Source notes / Game values** switches between source profiles and native game values; **Pause model / Rotate model** controls movement. **Switch ship - review trade** opens the exchange quote. Return opens specifications first, then the quote; Left/Right or Tab chooses Back or Confirm, and Return selects it. Browsing and reviewing a quote do not buy a ship; only confirming a valid trade changes your hull and balance. See [source units, estimates and attribution](SHIP-SHOWROOM.md).

## Help and MacBook keys

K, Command-K or Help > Player Key Guide opens help for the current activity; arrows change pages; Escape or K closes it. Help preserves the underlying search, list, selection or dialog. Command-P pauses/resumes; Escape resumes a paused game. Command-S saves the active file, Command-Shift-S chooses a save location, Command-O reloads the active file, Command-Shift-O opens another file, and Command-Q quits. Return/Space continues the displayed commander from the title or starts a new Commander Jameson after game over. Startup restores the last successfully saved commander in memory, waits at the title, and preserves the saved file; a first launch presents the automatic demo before the title. The title and opening credits display the app version, repository and full source commit SHA when bundled build metadata is available.

Delete means the ordinary MacBook key marked Delete or backspace, which erases to the left. Command-Delete clears an active search. Option-Up/Down is the documented paging combination; ordinary arrows and trackpad scrolling are sufficient for essential tasks. External keyboards may also send Page Up/Down and forward Delete; Fn-Up/Down and Fn-Delete remain optional macOS aliases. No essential action requires Home, End, Insert, Clear, a keypad or function keys.

## XYZZY options

Type XYZZY outside a search to become Commander Clarke in a fully fitted Cobra Mk III and open the secret menu. K gives its help, Escape returns to the game, and numbers select options here rather than game areas.

| Key | Option |
| --- | --- |
| 0 | Cycle white wireframes, coloured wireframes and shaded panels |
| 1 | Fit Docking targeting tier |
| 2 | Restore maximum hardware, shields and fuel |
| 3 | Toggle unlimited missiles |
| 4 | Toggle unlimited fuel |
| 5 | Show the current fuel/navigation jump limit |
| 6 | Toggle auto-trade, including illegal goods |
| 7 | Toggle speech |
| 8 | Toggle unlimited cargo, subject to selling excess before disabling |
| 9 | Show cash; initial XYZZY grant is 1 million CR |
| A | Toggle automatic target assistance |
| B | Toggle military return fire |
| C | Restore the Cobra Mk III and maximum hardware without a purchase; preserve cargo and mission progress |
| E | Toggle automatic ECM |
| F | Fit Fuel Scoops |

## Compatibility shortcuts

Experienced players can still use A for laser fire; X/S for pitch; comma/less-than and full-stop/greater-than for roll; slash/question-mark for braking; R for targeting; P for cancelling guidance outside charts and the navigation screen; in those browsers P toggles the profit scan. Left/Right in buy/sell screens still buys/sells one unit. B/U/L still open mission contacts, rumours and the gallery where appropriate. X outside showroom search clears its filter; B/R/C/V and comma/full stop still control its baseline, comparison and profiles, and Space controls rotation.

Existing browser-specific close aliases (L, N or U in their own browser) and Return in help, rumours or XYZZY remain available for compatibility. Escape is the single primary Back control shown throughout the UI. No compatibility shortcut runs while ordinary text is being entered in search.

Shipyard: click Switch ship, or Return to read specifications then Return again to review the quote, then Left/Right and Return to choose Back or Confirm trade. Escape cancels. Sort: click A-Z/Power; filters and selection stay in place. Source variants are enabled only when more than one profile exists. Status/inventory and chart/route scrolling stop at the viewport boundaries; hints appear only while content overflows.

XYZZY L (or clicking its row) resets legal status to Clean. Saved mission progress is preserved. Save/Save As: Command-S / Command-Shift-S. Reload/Open: Command-O / Command-Shift-O. The last successful save restores in memory on launch and waits at the title before continuing. Ordinary commander files restore docked at the saved system; current development versioned mission saves also restore their saved flight/world state, retaining mission ships and spent resources.

## Installed mission packs

**Commander > Install Mission Pack** selects a TOML file. **Game > Mission Gallery** lists valid packs and saved progress, including suspended entries. **Game > Mission Contacts** or docked **B** opens eligible contacts. Legacy dialogs use arrows for Confirm/Back. In script-choice dialogs, **Up/Down** browses answers and **Left/Right** selects Confirm/Back; **Return** or clicking Confirm submits the highlighted answer. **Escape** returns without an answer or pending transfer. Repeatable answers require a fresh offer and explicit confirmation each time. **Option-Up/Down** and trackpad scrolling read long dialogs. See the Gallery trial, campaign-review and retry controls under Station tasks above. The additional script controls describe development source, with final quality/release acceptance pending.

For **schema 2 Lua missions**, copy the whole pack folder into `~/.xyzzy/elite/script-packs/` and restart. The Install Mission Pack menu and `--validate-mission-pack` command apply to legacy TOML packs, not Lua folders. See [Schema 2 Lua mission authoring](SCRIPT-MISSION-PACKS.md). Generated courier jobs are bundled; other authoring examples require explicit installation.
