# fix(targeting): separate physical holds from extraction permissions

Catalogue capital vessels now receive a distinct targeting classification. With a fitted salvage module they use the existing safe physical surface-hold controller and immediate default cutter selection. Their mesh-derived guidance surface never installs physical salvage metadata, wreck identities, loot or custody on a live ship. Stations retain their existing docking selection.

Large rock/wreck/section parents can be held independently of abandoned ownership. Missing specialty modules produce ordinary tracking, preserving visibility rules and specialty filters, without work guidance or automatic weapon selection. A held occupied EMP hull keeps positioning independently of crew capture capacity; the unchanged native people producer still checks tools, deadlines, capacity and custody before any capture.

## Validation

Authored selection tests enumerate core tiers, visibility, independent modules, manual filters and protected large parents while retaining loose-item and occupied-pod refusal assertions. Runtime tests use an actual capital catalogue mesh, a real generated native salvage parent and current bound rock/equipment fixtures to check that holds grant no cutter authority and missing modules create no work controller or emission.

Strict Swift formatting, whitespace and paired Markdown lint are source checks. No compiler, native test, GUI or renderer job is run by this author. Focused acceptance and full `make ci` remain the integrator's responsibility after independent review. This leaf does not implement physical breakup/mass accounting or alter EMP effects, native custody producers, persistence formats or Script transactions.
