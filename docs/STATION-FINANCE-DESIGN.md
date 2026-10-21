# Station finance and campaign assignment design

Design handoff, 15 October 2026. The orchestrator assigns implementation; this specification changes no engine or UI code. Add a small Finance service to the existing docked station hub/contract-board architecture, with independent loan history and readable campaign assignment relationships. No new numbered screen or letter shortcut is required. Existing Market (7), Equipment (3), Shipyard (6), mission dialogs and painted-page confirmation contracts retain their owners.

## Scope and source rules

The governing research is [Iron Raven finance specifications](research/iron-raven-finance-specifications.md), especially Shared GSE loan and Calendar, save and acceptance. Its selected Iron Raven 2.0.2 profile and pinned Oolite credit setter establish the following rules. Earlier analysis notes saying the loan adaptation is undecided are superseded by that completed finance specification.

| Rule | Required behaviour |
| --- | --- |
| Optional offer | Accept, Defer or Reject; it is a loan, not a campaign reward. |
| Principal | 500,000 CR, issued once. |
| Nominal repayment | Fixed 550,000 CR; no recurring interest, collateral, bounty or extra penalty. |
| Calendar | Day = floor(commander calendar seconds / 86,400); due day = acceptance day + 60. Use the persisted game calendar, not the Mac date or time offline. |
| Short balance | Actual charge = min(real credit balance, 550,000 CR). Settlement still closes the obligation, including a zero-credit settlement. No residual debt or negative credits. |
| Default | On or after the due day, the next eligible Galaxy 8 main-station opportunity collects automatically before any manual repayment. Elsewhere, time passing or browsing does not automatically collect. |
| Independent lifetime | An accepted obligation survives parent completion, hull exchange and save/load. This is an explicit project repair, not a claim about unmodified callback behaviour. |
| Historical offer gate | Active owning campaign, shipment question 2, actual Ustiza/GSE contact, Galaxy 8; Defer allows a later decision, Reject is final. |

Generic native finance uses real main orbital stations. Adapting historical offices/facilities remains a separate capability: a generic service must not pretend that the whole Iron Raven campaign is installed or playable. Offer and manual-repayment eligibility are supplied by the native controller, with their station policy displayed. Do not infer a real facility from its display name. The exact hub entry slot remains an integration decision against the engine owner's current station/contract-board design.

## Entry and navigation

The existing station hub exposes **Finance** under its mission/station services, once, without a second hub. The row may show `1 outstanding` or `Payment due`. With no obligations/offers, it remains an understandable empty service: `No loans or offers` rather than a dead action. A campaign contact can link to its exact loan offer; this opens a review and never accepts automatically.

Finance contains **Outstanding**, **Offers** and **History** as labelled filter buttons, operated by the same existing pointer/focus controls. Keep the last filter and selected record during Back. Select a row with Up/Down or a click; Return opens details. Escape returns to the list, then hub. A short single-record list can present these sections on one page instead of introducing mandatory tabs. The precise focus traversal uses the centrally normalised navigation contract, not new finance-only bindings.

Loan details can also be read from the owning campaign's Gallery entry, including while flying. Outside an eligible station show the same information with a specific unavailable reason and no active transaction control. Reading a loan, Help, scrolling, painting, closing a window and Back must not create station opportunities or finance events.

## Screen states and player wording

Use the actual campaign/assignment title supplied by content, with `GSE loan` as the service name for this profile. IDs and content hashes belong only in optional Source notes. All amounts are real balances, even in XYZZY mode; an unlimited-spending policy is not an infinite repayment balance.

| State | Visible content | Actions and outcome |
| --- | --- | --- |
| Empty | No outstanding loans or available offers; brief explanation of campaign eligibility | Back; optional History if records exist |
| Offer unavailable | Creditor, campaign, terms and exact reason: required contact/station, inactive parent or unsupported facility | Read terms, Back; no Accept |
| Available or Deferred | Principal, nominal repayment, today, proposed due day, current and resulting balance, complete settlement terms | Accept loan, Decide later, Decline loan, Back |
| Outstanding, before due | Accepted day, today, due day, calendar days remaining, nominal amount and real balance | Review repayment when controller permits; otherwise reason and Back |
| Due, outside automatic eligibility | Due day, `Due — collection pending`, and `Automatic collection occurs at the next eligible Galaxy 8 main station` | Read details/Back; manual review only if the controller's explicit repayment policy permits it |
| Repayment review | Frozen balance, nominal amount, actual charge, resulting balance and `This closes the loan` | Repay / Back; default selection Back |
| Saving | Existing reviewed terms and `Saving your decision…` | Transaction controls disabled; no second action queued |
| Paid | `Paid — closed`, actual amount collected, settlement day and remaining balance from receipt | Read receipt, Back; no Repay or new principal |
| Defaulted | `Defaulted — settled`, actual amount collected, settlement day and explanation of automatic collection | Read receipt, Back; no Repay |
| Rejected | `Declined`, decision day and original offer identity | History/Back; no later Accept for this obligation |
| Stale review | `Your balance, location or loan changed. Review the updated terms.` | Review updated terms / Back; no transaction on the stale action |
| Save failed | `Your decision could not be saved. Your balance and loan are unchanged.` | Review again / Back; automatic collection uses the separate retry state below |

`Decide later` deliberately saves DEFERRED and closes the offer. Back merely dismisses it without changing the current offer status. `Decline loan` opens a small finality review: `Declining ends this offer. You cannot accept it later.` with Decline / Back, default Back. Acceptance has one review of all terms and an explicit **Accept loan** action; do not add a second identical confirmation. A deferred offer recalculates the proposed due day from the later acceptance day.

### Acceptance terms

The visible terms must say, in ordinary language:

> Receive 500,000 CR now. The fixed repayment is 550,000 CR, due on Day {dueDay}. On repayment, GSE takes up to 550,000 CR from your actual balance and closes the loan, even if you have less. No remaining debt or extra penalty is added. If still outstanding on the due day, collection happens automatically at the next eligible Galaxy 8 main station. The loan remains active after this campaign ends or you change ships.

Show `Today: Day {today}` and `Due: Day {dueDay}` above the terms. `60 calendar days` describes day boundaries; do not promise exactly 60 elapsed 24-hour periods. Show the actual controller's manual-repayment station policy alongside its action. If the complete principal would exceed the native credit limit, show a specific unavailable reason; do not silently grant a smaller loan while recording the full obligation. Historical-specific gates and generic-native adapters remain separately documented in Source notes.

### Repayment examples

| Real balance before | Nominal repayment | Charge now | Balance after | Result |
| --- | --- | --- | --- | --- |
| 700,000 CR | 550,000 CR | 550,000 CR | 150,000 CR | Paid — closed |
| 120,000 CR | 550,000 CR | 120,000 CR | 0 CR | Paid — closed |
| 0 CR | 550,000 CR | 0 CR | 0 CR | Paid — closed |

A short balance is not `Insufficient funds`: the selected source permits settlement. Explain `Your current balance is below the nominal amount. Paying {actualCharge} CR still closes this loan.` A zero balance remains an explicit reviewable settlement, not a disabled Repay button. Preserve exact fractional credits internally and format actual amounts consistently with the game.

## Automatic default and event ordering

Default is an engine event with a receipt, not a player choice. At day >= due, a genuine eligible Galaxy 8 main-station opportunity resolves it before accepting a manual repayment command. Opening Finance, returning from Help or repainting a page is not an opportunity. Preserve the engine's authoritative station identity, calendar and opportunity ID.

After the durable default transaction succeeds, present `GSE loan settled automatically` with nominal amount, actual charge, resulting balance and due/settlement days. The only action is Continue/Back acknowledgement. Leaving this receipt does not charge again; replayed acknowledgement never settles another record. If it interrupts another dialog, return to the previous context only after refreshing its validity; its old confirm token cannot act on the receipt or a replacement page.

Outside default eligibility, keep the loan due and pending without collection. Manual repayment availability is a separate explicit native policy: the UI neither broadens historical facility access nor treats being overdue as permission to collect at arbitrary stations. Any enabled manual action follows that policy and the same fresh-review contract.

If saving automatic collection fails, show `Collection could not be saved. No money was taken.` Keep the original obligation and balance plus the pending eligible event. Offer **Retry save** / **Back**. Retry revalidates the same pending event; Back acknowledges the failure, does not waive the obligation, and cannot unlock a manual bypass of pending default. A later real eligible opportunity may retry once through the engine's normal event rules. Never show a settled receipt before durable publication.

## Native contract required by the design

This is a semantic contract for the engine owner to map to its existing types, not a competing TOML schema or prescribed implementation API.

| Data or event | Required fields and meaning |
| --- | --- |
| Finance snapshot | Save/trial context identity, actual docked station ID/kind, galaxy/system IDs, persisted calendar seconds/day, real balance, revision, records and controller eligibility reasons |
| Loan record | Stable independent obligation ID; creditor and human title; owning campaign instance/root; original offer/acceptance identity; principal/nominal in exact game credit units; accepted day/due day; Offered/Deferred/Rejected/Accepted/Paid/Defaulted; immutable settlement receipt if closed |
| Review capability | Record ID/revision, actual balance and due state, expected context/station, allowed operation, fresh token, originating painted-page identity and quoted charge/result; any affected revision invalidates it |
| Read/open/filter/scroll/help/back | Read-only presentation changes; no financial proposal, station opportunity, deadline reset or principal grant |
| Offer actions | Accept / Defer / Reject against the exact offer review and painted identity; selection changes do not consume the token |
| Repayment | Explicit request with current review token; validate all conditions and settlement arithmetic inside native simulation ownership |
| Default opportunity | Genuine eligible station opportunity ID, calendar state and ordering provenance; once-only settlement before manual finance actions |
| Transaction result | Committed receipt, stale/eligibility reason or publication failure; include the actual updated immutable snapshot, never optimistic UI accounting |
| Receipt | Original obligation and cause/operation ID, amount charged/granted, balance before/after, calendar day, station identity, outcome and parent provenance; independent of parent cleanup |

Cash, obligation state, calendar/deadline effects and receipts commit together through the existing durable publication barrier. A failed save publishes none of them to live state. Replaying a successful token returns the same receipt or a harmless already-settled result, never another debit or grant. Preserve the accepted obligation if parent content is missing; inspect it and resolve through its supported native finance policy, or display the exact suspension reason without deleting it.

Revalidate on confirmation: save/trial context, exact record, status, offer/parent eligibility where applicable, location/station policy, actual balance, calendar day and due-default ordering. If any relevant value changed, reject the old action and require a newly painted review. Do not silently change the charge, substitute another offer or accept the next loan on queued Return/click. Two actions captured from one page cannot chain into the following page. Arrows followed by Return may still choose on that same visible review. Persisted expiry/receipt state and transient presentation tokens remain separate.

## Campaign and owned assignment Gallery additions

Retain the existing parent/child records and isolated trials. On a campaign detail page show **Assignments** with each actual human assignment title, its current outcome/status, objective and relation to that campaign. Distinguish Not started, Active, Complete, Failed and Suspended using labels as well as colour. Native status and suspension reason win over a guessed ordering or parent milestone count. Missing content remains identifiable without exposing hashes in the main UI.

Selecting an assignment opens its existing child detail page. Its header says `Part of {campaign title}` and includes **View campaign**. An owned-child row offers **Try campaign**, not Restart assignment. Explain `This assignment starts through its campaign.` Activating that action reviews the owning root campaign's trial; it does not start a standalone child, reset its live progress or reuse another campaign's completion receipt. If the exact parent content/trial capability is unavailable, explain that and disable the action.

Add **Finance** to the campaign details only when it has relevant offers/obligations/history. An accepted loan remains in global station Finance after the parent is complete. Campaign status and loan status are independent: a settled loan does not imply campaign success, and campaign completion does not erase the loan. No extra global Gallery tab is required.

Trials use separate commander, cash, calendar, obligation ledger, station opportunities, save namespace and painted identity. Show a persistent `Trial — live commander unchanged` label. Finance review in a child trial directs to the owning campaign trial. Seed valid offer/location/time cases only through the approved native scenario fixture; the Gallery cannot mark the historical campaign playable merely because its finance demonstration runs. Leaving a trial restores the real commander's exact finance and presentation context.

## Compact and wide layout

Use the existing fixed small logical font; Retina doubles pixels, not text size. At 512x518 logical points, reserve distinct header, scrollable content and pinned action/footer bands above the existing cockpit/dashboard. Put amounts and dates on separate labelled lines; avoid horizontal amount columns. Outstanding list and details are separate pages with one Back level. Keep nominal/actual charge and balance after visible immediately above Repay/Back, with full terms in the scrollable region. No action may cover text or the HUD.

Acceptance terms are longer than one compact page. Provide ordinary Up/Down or trackpad scrolling and the existing page-navigation alias, with an overflow indicator only when needed. Pointer choices and keyboard focus refer to the same controls. Accept/Decline/Repay must never be the implicit target of an opening or queued Return; financial review initially focuses Back, while offer action selection is deliberate and visible. All three offer decisions remain reachable without horizontal clipping.

At 1512x982 logical points @2x, use a bounded-width list and detail pane, preserving normal reading width instead of stretching text across the screen. Reserve a footer for actions. Changing list selection previews only; it must not select a financial decision automatically. Keep dates, status and amounts easy to compare. Resize preserves the current record, reading position and transaction identity; if controls change page identity, discard queued actions and repaint before a commit.

## Acceptance matrix for implementation

| Case | Required observable result |
| --- | --- |
| Offer Accept | One 500,000 CR grant and accepted receipt; due = floor(calendar/86,400)+60; subsequent open/reload cannot grant again |
| Defer then later Accept | No grant on Defer; later valid review uses its actual acceptance day; one grant total |
| Reject or Back | Reject commits final refusal only after its visible review; Back changes no business state |
| Full, short, zero balance | Review shows exact values above; manual settlement closes as Paid with no invented debt |
| Due equality | Day == due at eligible Galaxy 8 main opportunity defaults first; later manual token cannot debit again |
| Due elsewhere | Reading/flying/other-galaxy station access creates no automatic collection; show pending and controller-supplied manual eligibility |
| Wrong station/parent/unsupported adapter | Specific reason; no grant/debit; unrelated same-name station cannot qualify |
| Parent ended/hull changed/reload | Accepted record and real receipts survive; no new principal, erased obligation or parent completion inferred |
| Balance/day/location/status changed | Old review commits nothing; updated review requires fresh painted identity and deliberate action |
| Queued Return/click/double confirm | One visible decision at most; old input cannot accept another loan, reject a new offer or repay twice |
| Save failure in Accept/Defer/Reject/Repay/default | Original cash, obligation and receipts remain; accurate error; retry cannot duplicate an earlier committed transaction |
| Default receipt Back/Help/resize | Acknowledge/read only; no new opportunity or collection |
| Paid/Defaulted/Rejected history | Exact actual charge/result visible, with no active settlement or grant button |
| Parent assignment list | Every real owned child has title/status/owner; no standalone restart or unrelated completion credit |
| Child trial | Routes to owning root campaign trial with explicit trial context; live commander/loan/calendar/save untouched |
| Compact/wide and Retina | No clipping/overlap; all terms and actions reachable; fixed font, pointer/keyboard parity, meaningful overflow hints |

## Implementation boundary and handoff

The orchestrator resolves the pending hub entry slot with the mission-engine owner and assigns native finance/controller versus UI work. Historical source-profile facility support and full Iron Raven activation remain separately gated. Implementing this design does not enable unrelated financial products, interest accrual, debt resale, ship confiscation or campaign rewards. Add only the Gallery disclosure/actions listed above, preserving existing owned-child machinery.

Before marking delivery complete, verify the acceptance matrix through native transactions/save failures and real 512x518 / 1512x982@2 app flows. Preserve the actual source/cause/repair metadata in developer provenance and optional Source notes. Run repository-required CI under coordinated leases. Implementation PRs follow the current project review loop: request `@codex review`, fix every actionable finding, request review again until clean, then merge only after required checks. This document is a design contract, not evidence that those runtime checks have passed.
