# Align fixture assertions with actual capacity, save and mission identity

## Recorded failures

Full maintained CI 337 failed at `159b47322879bf09d51a661f1c1fbea3b85c4edf`. Six assigned methods in four test files recorded eight assertion headers: cabin and XYZZY saves expected schemas 21/22 while both actual operands were 26; two-cabin free hold expected 10 tonnes; a missing-pack passenger comparison used a pre-save Commander; three timed-mission assertions selected the catalogue's final row; and the scoop test expected a full hold at 35 tonnes before accessing a removed body. The scoop method then trapped on an out-of-range array access. Raw log: `/tmp/elite-full-review-ci-337/ci-337.log`, SHA256 `35e03ab03c2eb23b699dc277dfd8ba46f6f9dcc06380b7ffa9b8e7cdcd21f310`.

## Source-backed causes

The actual native SH023 hull has a 30-tonne hold and 15-tonne cargo expansion. Two five-tonne cabins leave 20 tonnes free. The actual XYZZY maximum fit includes the expansion, giving a finite 45-tonne hold; 35 tonnes does not fill it. The existing lower-scoop pickup can therefore remove the candidate before the old unchecked array access. The raw count operand was not evaluated, so candidate removal is inferred from the source capacity and pickup path rather than claimed as a printed operand.

Canonical save publication persists current mining policy and selects schema 26. It also publishes that state back to the live runtime. A missing-pack reload deliberately suspends the saved mission, so the whole-Commander baseline must follow the actual first save while allowing only that explicit suspension during reload comparison. The legacy timed mission's real catalogue row is projected from its installed state ID and digest; a built-in native people entry is appended after it.

## Required correction

Preserve all current game rules, exact capacity calculations, cargo/cash conservation, owned hardware and passenger custody. Fill the scoop fixture to its actual finite capacity before requiring the full-hold response, then require the retained candidate's count and identity before indexed mutation. Preserve actual no-scoop, lower/upper approach, once-only, unlimited policy, thargon and stored/refitted device checks.

Use exact schema 26 with strict reads. For passengers, independently derive the expected saved Commander with only current mining policy persisted, conserve all original property and mission/calendar state, and retain whole loaded equality after normalizing only the actual missing-content suspension. Select the timed legacy mission through its actual installed state ID/digest and corresponding catalogue index; keep exact terminal failure, milestone count, no payout and no outgoing retry checks. See the [PR handoff](PR-native-capacity-save-fixtures.md).

## Scope and validation

Exactly six existing methods/six expanded cases change in four test files, with one nested identity selector and this issue/PR pair. No production source or shared EMP helper changes. G1 exclusively owns the separate two EMP methods/three cases and diagnostic work. MC1 performs only source formatting/parsing, strict lint, Markdownlint and diff/scope/hash checks. CI 337 remains failed; compiler and native execution belong to G1 after Root reviews the frozen leaf. No runtime pass or mission readiness is claimed.
