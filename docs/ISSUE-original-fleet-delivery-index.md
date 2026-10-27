# Complete fleet delivery cannot enter the source compiler

The original-fleet compiler scans only replacement-hulls/, where the first 94 approved hulls live. The complete approved delivery now supplies 77 additional hulls in separate frozen batches, with effective native-LOD replacements for the first 28 additions. Scanning the old directory leaves valid geometry missing; copying dense draft meshes or assuming one path for every hull imports superseded data.

The delivery index is the authority for the exact 171 spec/hull joins. The compiler needs to consume those explicit paths, authenticate their fingerprints, retain original provenance and stream one hull at a time without changing approved data or claiming runtime readiness. See [implementation and evidence](PR-original-fleet-delivery-index.md).
