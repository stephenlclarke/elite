# Hull geometry and surface design

The effective accepted mesh remains the starting point, with the indexed historical input retained as audit provenance. Each per-ship TOML retains the original design intent and palette. Repair and specialise that hull; do not substitute a generic template and call it the same family. The new geometry contract must travel with its actual performance and fitting contract. SH123 has the explicit current-source exception below; its historical hash is not a request to revert its selected appearance.

## Physical coordinates and layouts

+Z is forward and +Y is up. The existing 77 metre-authored additions retain their measured source dimensions in the per-ID contract. The other 94 have explicit new layout estimates, not recovered measurements. Source coordinate units must be verified before conversion. A later verified active per-ID calibration, including SH025, must be retained and recorded instead of scaling it to an estimate. The estimates in this pack are authoring starting envelopes, not clearance acceptance.

Before activation, lay out actual cargo volume, crew spaces, access paths, equipment modules and weapon apertures inside the hull. Correct a target envelope where the layout cannot fit; record the changed dimensions and rerun only affected bounds/clearance checks. Uniformly normalising every hull to the same showroom radius is not a physical conversion. The showroom can normalise previews only if it labels actual dimensions and offers a common-scale view.

The native mesh must retain real openings and structural gaps, useful collision geometry and the recognisable silhouette. Target 128-256 native faces; the record's 512 limit is a review bound, not automatic permission to enlarge current solver cost. A necessary exception requires an explicit per-hull cost/clearance decision, not a global capacity increase or a single enclosing solid box. Detail meshes and textures may carry fine surface work without burdening native collision queries.

## Three distinct design languages

| Builder | Shape | Surface | Lighting |
| --- | --- | --- | --- |
| Human | Built assemblies with plausible cabins, service access, cargo doors, engines and tool mounts; a few clear major volumes | Sparse recessed panels, louvres, vents, inspection plates, instrumentation and piping; retain family palette | Drive emission, navigation/status lights and modest cabin light; avoid random luminous dots |
| Larvaal | Smooth grown shells, organs, ribs, arcs and deliberate empty space | Smooth jade surfaces with restrained organic folds and golden interiors; no human grilles stamped over every panel | Actual luminous core/organs; preserve accepted jade/gold family colours |
| Tithe Network | Orthogonal machinery blocks, racks, buses, clamps, radiator slabs and service sockets | Industrial functional construction; no cockpit, wings for looks, ornamental armour, crest or animal silhouette | Amber status, limited work illumination and actual drive/weapon emission; see TITHE.md |

Spacecraft do not need aerodynamic wings. Human fighter shapes may suggest a predator through compactness, direction and proportion without becoming literal birds. Existing family wings, rings and pylons remain when structurally useful and user-approved. Do not remove the Kestrel's accepted pylon deletion or restore an animal head/beak merely to match its name.

## Human panel detailing

Use the original three continuous texture channels with coherent world/family scale. Edges of each repeated tile must join across both axes without discontinuity in albedo, recess depth, normal or roughness. Do not make every tile an isolated dark spot. Keep detail sparse: broad clean plates with occasional long seams, inset vents, cable trenches, pipes and instrument clusters. A visible seam must lead somewhere; a grille must have a recessed dark cavity and structural frame. Large ships need larger structural panel divisions as well as small service details.

Preserve the accepted palette range rather than painting the whole fleet cyan or gunmetal. Variant markings and functional modules can change accents while the family remains recognisable. Check repeated textures at near, medium and distant views; microdetail must fade cleanly instead of shimmering. Native LODs do not need geometric screws, every pipe bend or texture-derived panel triangles.

## Cockpit connection repairs

All opaque inhabited cockpit structures must physically meet the hull or a modelled neck/platform. Glazing alone cannot supply structural support. Check actual triangle/component contact or overlap at the joint, not only axis-aligned bounding boxes. Cockpit, bridge support and hull share the same transform and scale in all renderers.

| Hull | Required repair |
| --- | --- |
| Buffalo SH013/014 | Keep the three cargo drums and upper deck. Add a short central bridge plinth welded into the upper deck; seat the cockpit on it. The glazing's lower rim must meet the opaque bridge frame. Retain the maroon upper panel and cream drums. |
| Wildebeest SH104 | Keep the broad open-throat tug and rear bridge. Raise a connected rear service tower from the rear deck to the cockpit base, with an opaque support column and access trunk. Do not close the working throat or suspend the cockpit above the tower. |
| Tapir SH105/106 | Preserve the protective hoop and passenger capsule. Join the upper cockpit to a short inhabited dorsal neck attached to the capsule; its framing is independent of the protective hoop. The hoop cannot be the only apparent connection to a floating cockpit. |
| All other human hulls | Inspect every cockpit from front, rear, top, side and a full rotation. Apply the same structural rule; the three reported examples are not an exemption list. |

Structural parts may overlap at hidden joints. Windows must not be buried below opaque surfaces. A successful repair preserves visibility, the intended silhouette and the real physical openings.

## Make use visible

Every record's `variantFeature` and `primaryUse` select the following concrete changes. Apply only changes that correspond to its actual fitting/capabilities.

| Use | Visible treatment |
| --- | --- |
| Interceptor/pursuit/racer | Reduced occupied/cargo volume, prominent compact drive block, minimal protrusions, narrow forward weapon apertures. No decorative drag requirement. |
| Strike/assault | Forward armoured shoulders and visible magazine access; missile hardware must match the finite capacity. |
| Heavy fighter/gunship | Thickened reactor/heat-exchange service section, directional weapon apertures and larger cooling outlets. |
| Command/patrol/EMP support | Connected sensor mast or inset array, serviceable electronics bay and the actual larger bridge/crew layout. No unsupported sensor or ally buff. |
| Recon/survey | Dedicated survey aperture, instrument service panel and recorder equipment access; preserve a relatively light silhouette. |
| Cargo | Clearly modelled drums, containers or a central hold with loading access. Bison uses exposed repeated container bays; Carabao uses a central rack; Warthog uses a protected enclosed hold. Keep these families different. |
| Tanker | Protected tank blocks and keyed service manifold. Differentiate Warthog Tanker from the freighter without promising unimplemented ship-to-ship refuelling. |
| Passenger/dropship/rescue | Connected inhabited deck, cabin access paths, airlock/receiver and life-support service section. Rescue uses a protected receiving throat and casualty handling access. |
| Miner/prospector/salvager | Real mining/cutter/scoop/survey apertures, recessed equipment sockets and wear concentrated around work areas. Distinguish prospecting instruments from extraction machinery. |
| Pirate/scavenger | Protected collection throat and patchable functional equipment; salvage variants show cutters/receivers, sprint raiders show engines/magazines. Do not add arbitrary spikes. |

Family marks retain a common keel, cockpit placement and engine lineage. Added cargo/endurance must correspond to a larger module or an explicitly repacked interior; a paint change alone is insufficient. Peregrine gains aft equipment/cargo volume across marks. Falcon gains service/armour/magazine volume and loses speed. Gyrfalcon Command has a wider inhabited electronics section; Assault has forward protection; Patrol has endurance/service volume. Harpy Dropship gets real cabin/receiver access; Gunship gets real cooling/weapon service. Osprey Support gets an equipment/recovery section, not an empty fighter bay. Warthog Light/standard/Tanker/Heavy have visibly different hold/tank arrangements.

## Protected Larvaal and Medusa work

Drone: keep the flattened ellipsoid, exactly three deeply recessed openings around its local horizontal plane and a visible luminous golden inner sphere. No extra ring, triangular green spike or independently tumbling band. The shell follows the ship's actual orientation; the ring pattern does not spin relative to it.

Warship: preserve the corrected bilateral nodule symmetry and close both unintended ring gaps. Sovereign: retain the accepted smooth grown construction and coherent ring/core design. Do not apply human panel textures to either.

For Sovereign SH123, the accepted current detailed display source is `branding-proposal/selected-ship.toml`, SHA-256 `2179227760376ed17b276153cb7cb20894f4f1bad5bf48e339b7dc874f70fe69`, as bound by the e10 original-model resource. The record separately retains historical `replacement-hulls/SH123-design.toml`/`a430c5e8...` as provenance. Preserve the selected display geometry; do not rebuild its appearance from that historical crescent-shell source. The record pins the e10 resource/hash separately. This is display authority only: author/calibrate native LOD, scale, inertia, bounds and openings independently while retaining that silhouette. No purchase, activation or physical calibration follows from branding selection. This correction does not edit or regenerate any geometry.

Medusa: retain the exact selected organic eight-pod crown, rounded continuous elliptical connecting band, rear-shifted hub, pod orientations, front/back inner green organs and curved projected dotted lines. Preserve the existing selected source hash before editing. Capability changes do not authorise changing the angles, adding a crystal, replacing pods with aircraft engines or returning to the older version. Only evidenced mesh/material defects may be repaired within those invariants.

## Media dependency

One maintained per-ship TOML must bind specifications, design source and referenced texture/material hashes. Its effective fingerprint includes those files and the renderer version. A change invalidates only that ship's portrait/rotating GIF and its central catalogue row; a shared texture change invalidates the ships actually using it. Do not regenerate all media on every unrelated edit. The central Markdown catalogue is generated from the same records and GIF paths. Repo README media remains game-renderer output through the maintained media workflow; SVG box diagrams here cannot replace it.
