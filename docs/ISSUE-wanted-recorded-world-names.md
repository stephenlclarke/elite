# Resolve PLUGH in retained wanted reports

Ledger M07.P01 / F21,F22,F25: WantedSighting accepts system256, the separate PLUGH world, but the dossier resolves location and reported destination only from the256 ordinary worlds. A valid supplied PLUGH report therefore displays Unknown. Scanner telemetry already has the correct ordinary/PLUGH identity resolver.

Reuse that existing resolver for recorded dossier identities, preserving the explicit galaxy prefix, nil/unknown behavior, historical-report wording and current plot-action guards. No new disclosure source, target, bounty, travel receipt or legal-state transition is introduced.
