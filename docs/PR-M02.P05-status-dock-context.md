# M02.P05.status-dock-context: Status follows actual docking state

## Change

`StationDockLocation` supplies the existing Status station row from actual docking state and the existing native station-name resolver. Flight reports "Not docked", known docks retain their names, and an unknown dock is explicitly unavailable. Status quantities, Inventory, docking receipts and service policies are unchanged.

## Validation

Three pure component methods cover seven cases, including retained dock metadata while undocked, main/waystation/headquarters names and an unknown dock. The maintained GitHub selection adds only these three methods to this independent branch's339existing methods. Swift execution and independent review remain pending.

Formatting, six Python report fixtures, documentation lint and whitespace checks are the authoring checks. No application build, integration, native journey, GUI, performance or release acceptance is claimed. This packet is disjoint from the station help, Inventory/Showroom and memo repair streams.

Parent: [M02.P05 / F07,F43](COMPLETION-LEDGER.md). The feature PR is the source/review handoff; usable-build and release states remain separate.

The actual canonical-base merge conflict is resolved by retaining both the three StationDockLocation methods and three NativeStationSnapshot methods. The final maintained union is345methods. Status source and its seven authored cases are unchanged; final-head GitHub checks and independent review remain pending.
