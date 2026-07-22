# CMHO — Workflows & Tasks

What a Chief Medical Officer of Health actually **does** in AshaMitra: every
workflow, what triggers it, where it happens, and what she does next.

Written against what is built and deployed. Where a task exists in her real job
but not in this app, it says so plainly rather than being quietly omitted.

> Visual spec and UI-generation prompts: `CMHO_UI_PROMPTS.md`
> Coverage against the official 14-area role: `CMHO_GAP_ANALYSIS.md`

---

## Her scope

District head of public health. Reports upward to the State Health Department;
downward she owns **BMHOs → ANMs → ASHAs**, every block, and every facility.

`জেলা → ব্লক → উপকেন্দ্র → ASHA`

Everything she sees is auto-scoped to her district. She never filters manually —
a BMHO opening the same screen sees only his block, from the same code.

---

## The rhythm

| Cadence | Workflow | Screen |
|---|---|---|
| Every morning | Clear the action queue | Dashboard |
| Within minutes | Respond to a RED push alert | Push → deep link |
| Daily | Check disease clusters | Operations |
| Weekly | Supply & cold-chain sweep | Supplies · Operations |
| Weekly | Chase silent workers | Dashboard → Workers |
| Monthly | Programme review | Programmes |
| Monthly | Performance review + state report | Analytics → PDF |
| Event-driven | Death review · Outbreak · Stockout | see below |

---

# A. DAILY

## A1 · The morning sweep — "what must I fix today"

**Trigger:** she opens the app.
**Screen:** Dashboard → **আজ যা করতে হবে**

One ranked list pulling from every source in the system. Ranked by how fast the
thing harms someone, not by which module produced it:

| # | Item | Why it ranks there |
|---|---|---|
| 1 | Disease cluster in a village | Still preventable; moves in days |
| 2 | MgSO4 / oxytocin / blood missing | Eclampsia and haemorrhage are the two biggest direct killers |
| 3 | Maternal or infant death | Review already mandatory |
| 4 | Cold-chain failure | Spoils a whole block's vaccines, silently |
| 5 | Open outbreak | Response already under way |
| 6 | Stranded referral (>7 days) | A woman referred who never arrived |
| 7 | TB doses missed · high-risk NCD | Drug resistance forming |
| 8 | Silent ASHA (30 days) | Zero-reporting — she may have stopped working |
| 9 | Immunisation defaulters | Named children overdue |
| 10 | **"খবর নেই"** — places that haven't reported | Never dropped; silence is not health |

**Her actions:** tap any row → the detail screen with the named people → call
directly from the row, or instruct the BMHO below her.

**Design note:** items 1–4 are the ones where acting today changes an outcome.
Item 10 is ranked last but never omitted — if it were dropped, a district where
nobody reports would look identical to one where everything is fine.

---

## A2 · Responding to a RED alert

**Trigger:** an ASHA's triage flags a RED danger sign. Push arrives on her phone
within seconds — channel `ashamitra_alerts`, HIGH importance, **wakes the app even
when it is closed**.

**Chain:** ASHA → her ANM → BMHO → CMHO. Every level is notified; none is skipped.

**Her actions:** tap the notification → lands on the case → confirm the BMHO has
acted → escalate transport or a facility bed if not.

**Verify it works:** Profile → **নোটিফিকেশন পরীক্ষা করুন**. Sends a real push and
reports the true failure reason if it does not arrive. A supervisor who cannot
confirm her own alerting is one rung of a broken escalation chain.

---

## A3 · Disease surveillance

**Trigger:** daily check, or the dashboard shows a cluster.
**Screen:** Operations → **রোগ নজরদারি**

The system compares **each village against its own** preceding 3-week average —
never against other villages, which would flag the largest village every week.

Two rules fire a cluster:

| Rule | Condition | Catches |
|---|---|---|
| **Spike** | ≥2× its own baseline, min 3 cases | A village whose fever load has doubled |
| **Novel** | No baseline at all, ≥4 cases | Point-source outbreak — cholera in a village that never had it |

Every cluster **states why it fired** — *"স্বাভাবিক 1.3 → এখন 5 (3.8× বেশি)"* or
*"আগে এই রোগ ছিল না — হঠাৎ 4 জন"*. An alert she cannot audit is one she will stop
trusting.

**Her actions:** review the named patients → deploy the RRT → open an outbreak
record (A4) → order water testing / chlorination / vector control.

---

# B. EVENT-TRIGGERED

## B1 · Maternal or infant death → MDSR / CDR

**Trigger:** an ASHA records a death via Vital Events. Escalates immediately.
**Screen:** Dashboard queue → Programmes → **জন্ম-মৃত্যু নিবন্ধন (CRS)**

**Her actions:** open the case → convene the death review (MDSR for maternal, CDR
for child) → record findings → confirm CRS registration.

**Not in the app:** the MDSR/CDR proforma itself. The app surfaces *which* deaths
need review and whether registration happened; the review document is a separate
state process.

## B2 · Confirmed outbreak

**Trigger:** a cluster she judges real.
**Screen:** Operations → **প্রাদুর্ভাব ও জরুরি অবস্থা**

Opens an outbreak record carrying the standard public-health checklist. The screen
shows **what has NOT been arranged yet**, not what has:

`RRT পাঠানো · জল পরীক্ষা · খাবার নমুনা · ক্লোরিনেশন · ORS ক্যাম্প · মেডিকেল ক্যাম্প ·
অ্যাম্বুলেন্স · সচেতনতা · মশা নিয়ন্ত্রণ`

Also covers flood, cyclone and epidemic — same checklist, same review.

## B3 · Life-saving stockout

**Trigger:** an ASHA or ANM marks a critical item **নেই**. Pushes up the chain
instantly.
**Screen:** Supplies → **প্রাণরক্ষাকারী জিনিস নেই**

Critical items: `BP মেশিন · অ্যাম্বুলেন্স (102/108) · Inj. MgSO4 · Inj. Oxytocin ·
Tab. Misoprostol · FRU-তে রক্ত · রাতে সিজার`

**Her actions:** see who and where by name → arrange transfer from a stocked
facility or issue an emergency indent → confirm on the next report.

**Why this ranks so high:** a woman who dies of haemorrhage or eclampsia usually
was not undiagnosed. She died because the drug was not there, or the ambulance did
not come. This is the half of mortality a triage app alone cannot touch.

## B4 · Cold-chain failure

**Trigger:** an ILR reading outside **2–8°C**, equipment not working, or a power
cut ≥4 hours.
**Screen:** Operations → **কোল্ড চেইন**

Failures and **silence** are counted separately — a point that has not reported is
not a working fridge.

**Her actions:** move vaccine stock to a working point → repair or replace →
confirm the shifted stock was recorded.

---

# C. WEEKLY

## C1 · Supply & readiness sweep
**Screen:** Supplies

The **ব্লক × ওষুধ/যন্ত্র heatmap** shows the whole district at once: rows are
supplies (critical first), columns are blocks. Red = নেই, amber = কম, green = আছে,
**grey = খবর নেই**.

Coverage donut has **three** slices — reported / stale / never. Two would let a
district where nobody reports look identical to a healthy one.

**Her actions:** chase blocks that have not reported → arrange transfers → drill
into a block to see individual sub-centres.

## C2 · Silent workers
**Screen:** Dashboard queue → Workers

Zero-reporting is a recognised HMIS alert. An ASHA with no completed visit in 30
days is either unsupported, unwell, or has stopped.

**Her actions:** name and block are shown → call directly → instruct the BMHO to
visit.

---

# D. MONTHLY

## D1 · National programme review
**Screen:** Programmes

| Programme | She acts on |
|---|---|
| **যক্ষ্মা (NTEP)** | **Doses missed** (resistance forming) · **not in Nikshay** (invisible to the state, drugs not requisitioned) · sputum results pending |
| **NCD** | CBAC ≥ 4 needing confirmatory testing · referred with no follow-up date |
| **পরিবার পরিকল্পনা** | **Unmet need** — prioritised by youngest child under 1, because a short birth interval is the highest-risk next pregnancy |
| **CRS** | Deaths needing review · unregistered births (a child with no legal identity) |
| **ওষুধ** | Lines below threshold |

Every row names a person and carries a phone button.

**Absent, and stated on-screen:** malaria/dengue surveillance beyond syndromic,
leprosy, blindness. No collection exists. The note stays visible so a missing
programme cannot read as a healthy one.

## D2 · Performance review & state reporting
**Screen:** Analytics

1. **HMIS মূল সূচক** — institutional delivery, C-section, LBW, ANC, immunisation,
   PNC, maternal/infant deaths, referral closure. `—` where there is no
   denominator, never `0%`.
2. **মাসে মাসে কাজ** — real month-by-month bars. Reports and RED overlaid on one
   chart so the ratio is visible. Warns out loud when the current month is empty
   against a non-empty history.
3. **লক্ষ্যের তুলনায়** — each indicator against its reference, **sorted by
   shortfall**. The first question in a state review is "why is immunisation 79
   points below reference" — this puts the answer at the top.
4. **Rankings** — blocks and BMHOs, worst first.
5. **PDF export** — the monthly review document. States in print that "—" means
   no denominator, not zero.

## D3 · Facilities, staffing, QA, training, meetings
**Screen:** Operations

- **স্বাস্থ্য কেন্দ্র** — every facility, and those with **no 24×7 delivery**, a
  direct Delay-3 signal.
- **কর্মী ও শূন্যপদ** — sanctioned vs in-post per cadre, biggest gap first.
  *"3 of 5 ANM posts vacant at Kalyani BPHC"* is a posting decision.
- **পরিদর্শন ও মান** — scores below 70%, plus facilities **never inspected**.
- **প্রশিক্ষণ** — attended vs invited.
- **সভা ও সিদ্ধান্ত** — only the **open action items** with owner and due date.
  A decision without an owner and a date changes nothing.
- **বাজেট ব্যবহার** — allocation vs spend, lowest utilisation first.

---

# E. Task → screen index

| Task | Screen | Route |
|---|---|---|
| See what needs me today | Dashboard | `/admin` |
| Respond to a RED alert | push → case | — |
| Check disease clusters | Operations | `/admin/operations` |
| Open / track an outbreak | Operations | `/admin/operations` |
| Fix a life-saving stockout | Supplies | `/readiness/summary` |
| Cold chain | Operations | `/admin/operations` |
| TB adherence & Nikshay | Programmes | `/admin/programmes` |
| NCD high-risk follow-up | Programmes | `/admin/programmes` |
| Family planning unmet need | Programmes | `/admin/programmes` |
| Birth/death registration | Programmes | `/admin/programmes` |
| HMIS indicators & trends | Analytics | tab 2 |
| Rank blocks / BMHOs | Analytics | tab 2 |
| Monthly review PDF | Analytics | tab 2 |
| Facilities & staffing gaps | Operations | `/admin/operations` |
| Inspections · Training · Meetings · Budget | Operations | `/admin/operations` |
| Worker roster & performance | Workers | tab 3 |
| All triage reports | Reports | tab 4 |
| Test my own alerts | Profile | tab 5 |

---

# F. Not in the app — and why

Her real job includes these. The app does not do them, and pretending otherwise
would be worse than the gap.

| Task | Why not |
|---|---|
| Leprosy · blindness programmes | No collection exists. Adding empty tiles would imply zero cases in a district never asked. |
| Malaria/dengue beyond syndromic | Syndromic surveillance and RDT results are captured; vector control operations are not. |
| Leave · postings · salary · promotions | Belongs in a government HR system with legal records. A parallel copy creates disputes over which is authoritative. |
| Budget approval · audit · payment | Needs treasury integration and an audit trail. The app shows **utilisation only**, and says so on the card. |
| MDSR / CDR proforma | The app flags which deaths need review; the review document is a separate state process. |
| State HMIS upload format | All the data exists. The specific upload template must come from the actual state form, not an assumption. |
| Procurement & indent workflow | Stockouts are surfaced; the purchase process is not. |

---

# G. The rules this panel holds to

Seven decisions that outrank any visual preference, because breaking them
produces a screen that is *confidently wrong* — worse than one that says nothing.

1. **`—` is not `0`.** No denominator means unmeasured. "0% institutional
   delivery" reads as catastrophe; the truth is "no births recorded yet".
2. **Grey is not green.** A sub-centre that never reported is not a stocked one.
3. **Show the denominator or suppress the number.** `50.0%` from n=2 is one woman.
4. **Actions lead, totals follow.**
5. **Names, not rates.** Every aggregate drills to people with a phone number.
   A supervisor acts on *"Rahim Sheikh, 4 doses missed, Kolkata"*, never on "87%".
6. **Trend arrows are coloured by meaning.** ↑ immunisation green, ↑ maternal
   deaths red, ↑ C-section neither — it is a range (10–15%), and both directions
   signal a failing system.
7. **Say why an alert fired.** *"normal 1.3 → now 5, 3.8×"*. An alert that cannot
   be audited will eventually be ignored.
