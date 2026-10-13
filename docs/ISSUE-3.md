# Resolve Sonar maintainability findings in rendering helpers

The committed-main scan passed its quality gate but reported 18 maintainability findings: nested conditional expressions, deeply nested catalogue closures and two rendering helpers with too many scalar arguments. Simplify those maintained sources while preserving gameplay, clipping, target ordering, gallery states and generated artwork.

Implementation: [PR-3.md](PR-3.md).

Pull request: <https://github.com/stephenlclarke/elite/pull/3>.
