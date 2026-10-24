# G13 mutual contribution: executable queue handoff

Approved by Root on 20 October 2026 for G3/MBA implementation after W03
integration. Exact14-path scope and Cedamar recipient are approved. This handoff
records the assignment, not implemented or tested source. M01 keeps first
resource priority.

## Scope and authority

- Existing ledger item: **G13 / M05 / F35 / K09**,
  `l337.contract/mutual-contribution`, Mutual relief contribution.
- Authored source: `original-missions/original-families.json`, exact G13
  template, and its Markdown counterpart in this design workspace. Approved
  design fixes a voluntary 500CR contribution, zero cargo/berths/deposit/cash
  reward/deadline and its own first-success clue.
- Source inspected at canonical `33304385e7327b13288bb2aa0d3685a01ac59d3c`,
  which includes W03. G1 supplies the actual dispatch base.
- Approved receiving account: **Cedamar Orbital Relief Reserve**, actual Cedamar
  G0/S85 main orbital station. No new monetary tuning is needed.
- Outcome: station-board review names the reserve and exactly 500CR; deliberate
  Donate commits the real debit and recipient acknowledgement, then the exact
  successful G13 terminal qualifies its one PLUGH clue. Back changes nothing; no
  fictional profit, standing privilege or travel requirement.

## Existing native transaction contract

Reuse `ScriptPledge.swift` preview/resources/`applyPledgeCommand`,
`ScriptPledgeLedger.swift` and `ScriptContractCore.swift`
acceptance/publication. The current board already has Donate and the current
writer already persists the ledger and clue.

The native action must retain all existing non-Codable admission checks:
instance, actual station/epoch, board/offer/revision/digest, event sequence,
original before-assets and sufficient full cash. Add the exact G13 current
native dock/recipient check; no remote or paused donation. One native
`pledge.commit` performs the debit and records the existing receipt, then
completes the zero-reward contract inside that same candidate.

The G13 qualifying receipt must pass existing
`ScriptPledgeReceipt.valid(engine:)` and join ALL of:

- Exact G13 definition, approved version/digest, declaration/profile and named
  reserve at G0/S85; matching owner/current native dock and retained causal dock
  evidence.
- `variant == credits`, difficulty1, `amount == 5000`, unit `decicredits`;
  original before.cash is sufficient and after.cash equals before.cash
  minus5000. Food/cargo are unchanged.
- Receipt identity derived from this instance; unique acknowledged sequence,
  original board/offer and matching pledgeReceiptID.
- The same instance is complete; its actual contract is settled with complete
  outcome and settlementAmount0, joined to its real completion receipt. No
  reward/refund or separate credit command.

Use the existing validated recipient receipt history as the contribution account
acknowledgement; do not add another balance/ledger. Its existing issuer counter
may remain an internal receipt count, with no advertised rank/trading bonus.
Preserve existing retained-record limits.

## Actual implementation gaps

1. The current pledge profile requires six credit/Food rows. Add one closed G13
   profile with `creditAmounts = [5000]`, `foodTonnes = []`, only `credits-1`,
   at the exact receiving station. Existing providers retain six rows and all
   their checks.
2. Replace inherited Station Aid/estimated-standing terms only for G13 with
   original fund/debit/acknowledgement text. Lua produces the one row and
   requests the existing native commit last; it cannot debit, pay, alter
   standing or award clues directly.
3. A completed native pledge currently has completion cause `mission.accepted`.
   Generic clue pins intentionally refuse that cause. Preserve this rule for
   ordinary acceptance. Add only a closed G13 qualification requiring the
   COMPLETE valid native receipt above, both when awarding and validating a
   retained journal. Do not fake a dialogue event or treat
   acceptance/milestone/pledgeReceiptID alone as success.

Exact clue: `mutual-contribution-family-trace`; receipt
`l337.unwritten-route/clue/mutual-contribution-family-trace`. Source count
stays64. Repeat real donations cost another 500CR but retain the same
first-success clue.

## Approved scope and implementation ownership

Root approved the exact14 paths. G3/MBA owns their implementation, content and
focused units; G2 independently reviews the complete boundary only after owner
PASS. G1 owns source composition, the current ledger and final integration. The
shared clue-authority hunks are identified separately below so Root can
reconcile any active MC1 reservation before edits; no MC1-owned path is
authorised.

MBA/G3 paths, relative to the selected repository base:

1. NEW `Sources/EliteCore/OriginalMutualContribution.swift`: closed G13
   constants and actual receipt predicate used by the consumers below; no new
   state or generic framework.
2. `Sources/EliteCore/ScriptPledgeLedger.swift`: only G13
   definition-valid/amount branches; retain existing receipt and six-row
   invariants.
3. `Sources/EliteCore/ScriptPledge.swift`: exact G13 profile/recipient/native
   dock checks and fund-specific review/acknowledgement text, using the existing
   transaction.
4. `Sources/EliteCore/ScriptContractCore.swift`: ONLY `ensureContractBoard`'s
   pledge expected-row hunk permits the exact one-row G13 declaration; all other
   providers still require six.
5. `Sources/EliteCore/ScriptBundledPacks.swift`: exact production discovery and
   same-digest deduplication.
6. NEW `Tests/EliteCoreTests/OriginalMutualContributionNativeTests.swift`:
   native declaration/receipt/protection units owned by the implementation
   author.
7. NEW `Tests/EliteCoreTests/OriginalMutualContributionTests.swift`: actual
   board/Donate/publisher/reload/clue flow.
8. `Tests/EliteCoreTests/BundledScriptPackTests.swift`: directly affected
   default/dedup expectations only.
9. NEW `Resources/ScriptPacks/l337-mutual-contribution/manifest.toml`, relative
   to `Sources/EliteCore/`.
10. NEW `Resources/ScriptPacks/l337-mutual-contribution/scripts/main.lua`,
    relative to `Sources/EliteCore/`.
11. NEW `docs/ISSUE-original-mutual-contribution.md`.
12. NEW `docs/PR-original-mutual-contribution.md`.

Shared clue-authority paths13/14, within the same G3 implementation scope:

- **Path13:** `Sources/EliteCore/ScriptBaseClueCatalog.swift`: closed exact-G13
    qualification and exact frozen production execution pin. No general
    acceptance-event whitelist expansion.
- **Path14:** `Sources/EliteCore/ScriptClueJournal.swift`: call the actual G13 receipt
    predicate in `awardScriptClue` and `journal.valid`; generic accepted,
    incomplete, foreign or stripped receipts remain refused.

These two clue-authority files are the shared boundary. No MC1-owned Game,
ScriptDirector, save/publication/preflight/envelope or equipment path is
proposed. If Root's current reservation register assigns either shared clue hunk
to MC1, Root resolves that exact ownership before central edits; do not add a
Director hook as a workaround. G1 owns the ledger as usual.

`ScriptClueVersionedSave.validateClaims` already delegates to journal.valid and
the exact trust pin; no edit or new save representation is proposed. If actual
implementation proves an extra persistence/schema path necessary, stop for
Root's exact reservation. Do not weaken existing validation or add a migration
framework.

## Focused acceptance and delivery

- One visible500CR Donate row, correct named actual reserve and no cash
  profit/standing privilege. Back/Decline, stale confirmation, wrong dock
  or499.9CR leaves full commander/receipt/clue unchanged.
- Exactly500CR reaches zero cash with one valid credited recipient receipt and
  zero reward. Ordinary acceptance without that receipt, forged marker, wrong
  amount/fund/digest or replay cannot award a clue or double debit.
- A second legitimate donation costs 500CR again; first-success clue remains
  once and no other source is satisfied. Respect retained receipt limits and
  real cash.
- Actual filesystem writer failure conserves full commander, offer, recipient
  receipt and clue. One valid retry publishes exactly once.
- Current Normal/Alien cold reload, alone and composed with W01/W02/W03, retains
  valid joins and rejects stripped/foreign receipt or clue claims; no new
  version assumed.
- Directly affected existing six-row credit/Food pledge behavior remains
  correct. No broad suite or unaffected reruns.
- Native loader validates the frozen production pack/digest before its pin is
  committed. Each implementation owner ensures focused PASS, then one
  independent complete-boundary bugs/performance/style review is CLEAN before G1
  integration.

Known limits: this is a local voluntary contribution, not a new financial
simulation or mission campaign. Artwork is already authored; no artwork pipeline
is part of this task. Root has approved content and the14-path scope and will
dispatch the author. No playable application, complete M05 or release claim
follows from this handoff.

## Approved hourly-offer amendment — 20 October 2026

Root approved a demonstrated native cadence dependency. This amendment
supersedes the earlier 14-path total: the approved scope is now **15 paths**,
with the same G3/MBA implementation ownership, G2 review after owner PASS and G1
composition/integration.

The fifteenth path is `Sources/EliteCore/OriginalContractOfferPolicy.swift`.
Only two exact closed G13 dispatch hunks, after installed-pack/digest
validation, are authorised. Every other Original stable-offer policy remains
unchanged. G3 has already been authorised by Root; no additional design or work
item is opened.

The existing native pledge receipt requires board revision `floor(localSeconds /
3600)`. The stable Original +2 revision policy cannot substitute for that native
hourly revision. Preserve the existing clock and receipt validity; add no
clock/state, fabricated refresh or receipt exception.

The board must truthfully explain that one valid donation consumes the existing
hourly offer. Replaying that same offer fails without another debit or clue. The
next genuine refreshed hourly offer may accept another 500CR donation; it
creates its own real native receipt while the G13 first-success clue remains
once only. This offer cadence is not a new mission deadline.

Focused qualification includes same-offer replay refusal and the next actual
native hourly refresh/debit/receipt, alongside the already-required rollback,
recipient, zero-profit and clue checks. Do not advance an unrelated clock or
apply the stable-policy +2 path to make those assertions pass. No new state,
schema, receipt weakening or change to other Original families is authorised.
