# Licensing and third-party notices

Copyright (c) 2026 Stephen Clarke. The original Swift implementation, tools, tests and original documentation are available under the [MIT License](LICENSE). Third-party material and adaptations retain the terms identified below; the MIT licence does not replace those terms.

## Ship models

The numerical meshes in [individual ship TOMLs](Sources/EliteCore/Resources/Ships) are adapted third-party artwork. Each entry has its own `license`, source identity and source file hashes. The current collection contains 56 models under CC-BY-NC-SA-3.0, 14 under CC-BY-NC-SA-4.0, one under CC-BY-SA-3.0 and three ADCK Eagle models under the author's public-domain declaration. Model adaptations remain under the corresponding source terms. This is a mixed-licence distribution: the MIT code licence does not permit commercial use of the included NonCommercial artwork.

Full Creative Commons legal codes are included here and in the app resource bundle:

- [CC-BY-NC-SA-3.0](Sources/EliteCore/Resources/Legal/CC-BY-NC-SA-3.0.txt): attribution, noncommercial use and share alike.
- [CC-BY-NC-SA-4.0](Sources/EliteCore/Resources/Legal/CC-BY-NC-SA-4.0.txt): attribution, noncommercial use and share alike.
- [CC-BY-SA-3.0](Sources/EliteCore/Resources/Legal/CC-BY-SA-3.0.txt): attribution and share alike.

[Asset attribution](Sources/EliteCore/Resources/ASSET-NOTICE.txt) identifies source versions and modifications. Full original credits, copyright statements, disclaimers and additional author terms are retained without alteration in [ModelLicenses](Sources/EliteCore/Resources/ModelLicenses), [Oolite-LICENSE.txt](Sources/EliteCore/Resources/Oolite-LICENSE.txt), [Vector-MANIFEST.txt](Sources/EliteCore/Resources/Vector-MANIFEST.txt) and [RescueStations-LICENSE.txt](Sources/EliteCore/Resources/RescueStations-LICENSE.txt). The two ModelLicenses indexes record each notice's original archive path and SHA256. The catalogue and retained model research identify the exact source archives and model/definition hashes.

Oolite core artwork is used under its CC-BY-NC-SA-3.0 option; its engine and other code are not included. The ADCK geometry declaration excludes Simon Bridge shaders, which are not included. See the [retained declaration](Sources/EliteCore/Resources/Legal/ADCK-declaration.txt) and original ADCK readme. Conflicting or unresolved asset permissions do not qualify a model for inclusion.

## Adaptations and attribution

Mesh adaptations by Stephen Clarke / XYZZY include DAT decoding, camera-axis reflection, winding reconciliation, source subentity transforms, JSON conversion and radius normalization. The previews omit source textures, shaders and flashers. These changes are not presented as the authors' original files or as an endorsement. Original Elite, Frontier, First Encounters and Elite Dangerous designs remain attributed to their respective creators; an Oolite rendition is labelled as such.

Elite was created by David Braben and Ian Bell. The project credits Mark Moxon's [annotated Elite sources](https://elite.bbcelite.com/) as historical implementation research. The original game, its ROMs and its assembly source are not distributed under this project's MIT licence. Ship facts, historical names and source references in the catalogue do not grant rights to the referenced games or assets. Upstream research extracts and notices retain their original rights.

## BBC-derived material

The numerical Constrictor/Thargon blueprints in `Sources/EliteCore/NavalShips.swift` and any retained original Elite narrative or design material are excluded from the MIT grant. The renderer, native control/simulation implementation and original explanatory prose are separately authored; those additions do not relicense the underlying material.

The [pinned BBC source repository](https://github.com/markmoxon/elite-source-code-6502-second-processor/tree/9080bd09c814b43c9c82571493c74bfb447aa607#a-note-on-licences-copyright-etc) explicitly supplies no licence and retains original copyright. Public source availability, attribution and a noncommercial project are not a reuse licence. This repository does not claim permission to sublicense that material or that the complete game has been cleared for redistribution. See the bundled [BBC provenance notice](Sources/EliteCore/Resources/Legal/BBC-PROVENANCE.txt). The original rights remain with their holders.

## Distribution

Renderer-generated `docs/elite.png`, `docs/start-sequence.gif`, `Resources/Elite.icns` and `docs/images/elite-icon.png` contain the adapted Oolite Cobra Mk III and are distributed under CC-BY-NC-SA-3.0, with attribution to the Oolite artwork contributors above and Stephen Clarke for the native rendering/composition. Their generation by this project's renderer does not turn the depicted model into MIT artwork.

Keep the applicable copyright, attribution and licence notices with redistributed material. The standard app build includes this notice, the MIT licence, all bundled asset notices and the Creative Commons legal codes in `Elite.app/Contents/Resources`. Preserve the per-model licence metadata and additional source terms when redistributing adapted meshes or renderer-generated media containing those meshes.

## Individual ship definitions

The runtime ship catalogue and numerical geometry now live in `Sources/EliteCore/Resources/Ships/*.toml`. The 74 imported models retain the original terms and custody metadata in each definition and the preserved asset notices. Ninety-four original project designs are MIT licensed. Generated GIFs depict each definition and follow that design's listed terms; the central source/design appendix records the distinction. TOMLDecoder 0.4.5 is MIT licensed, with its full notice packaged in `Legal/TOMLDecoder-LICENSE.md`.

## Liberator DSV2 adaptation

The Liberator mesh and material authoring code are project-authored interpretations of the Blake's 7 spacecraft, with visual attribution and adaptation limits in [docs/LIBERATOR.md](docs/LIBERATOR.md). Tony Gardner's ArtStation artwork and other reference images/models are not included. The project's MIT terms cover its authored implementation and mesh data, and do not grant rights to the underlying television property or external reference artwork.

Imported DAT face triples, texture names and UV mappings are retained as source metadata with model hashes. Referenced bitmap textures are not bundled or rendered; their rights are not inferred from geometry licences. Native per-face palettes and newly authored surface details are explicitly project adaptations.
