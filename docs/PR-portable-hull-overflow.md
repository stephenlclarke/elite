# Retain portable hull-exchange overflow

Packet: **M02.P03**, portable fitting transfer slice.

## Problem and behavior

Hull transfer previously remapped every fitted portable item to the destination hull and then rejected unsupported slots. That required manually storing equipment even though the owned inventory already distinguishes held and fitted items, and the approved exchange behavior requires retaining unfitted overflow.

A pure owned-inventory transfer now keeps compatible installed slots within the destination family limit and stores unsupported or excess portable fittings. It preserves item IDs, components, acquisition provenance, preferred slots and existing stored state. Hull-bound fittings still leave with the sold hull. Unknown nodes/owners, invalid contexts and exhausted revisions refuse without publishing a candidate. Returning to a larger hull never silently refits stored spares.

Commander projection and committed exchange use that same transfer operation. The quote checks projected active lasers/missiles, so retained stored devices do not falsely block it. Actual cargo/fuel, protected people/property and cabin constraints, prices, route checks, event capacity and candidate publication remain unchanged. The quote and player guides explain storage.

## Isolated verification and limits

Four new component-value methods use actual SH023/SH001 catalogue fitting contexts to cover smaller-hull overflow and complete item/component history, family limits independent of slot support, larger-hull return without refitting/recreating bound property, and foreign/unknown/exhausted refusal without changing the source. They instantiate no Game or GameRuntime. The fixed GitHub selection contains these methods; all six Python report fixtures pass locally.

Swift compilation/unit execution and MBA review are asynchronous in GitHub. No unrun Swift result, whole hull-trade/save journey, integration, GUI, app or release acceptance is claimed. Existing atomic trade/occupied-cabin and resource-refusal tests remain intact and are not executed wholesale in this phase. This slice does not replace the rest of M02.P03 or imply a source push is a playable delivery.
