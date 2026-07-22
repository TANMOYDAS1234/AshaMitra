# BMHO Panel — Design Spec & Stitch Prompts

> Read `PANEL_DESIGN_SYSTEM.md` first. Paste its **§6 preamble** before every prompt below.

---

## Who this is for

The **Block Medical Officer of Health** runs one block — a PHC or BPHC and the sub-centres under
it. She is the hinge of the whole hierarchy: close enough to know the ANMs and ASHAs by name, senior
enough to move a supply, sanction transport, or escalate to the district.

She is the person a RED alert usually reaches *first*. When an ASHA flags an eclampsia case at 2am,
the escalation chain fires **her** phone. So her panel is less about district-wide statistics and
more about **her own people, right now** — who is in trouble, who has gone quiet, what her sub-centres
are out of.

**The screen must answer: _who on my team needs me today, and what do they need?_**

Scope: `ব্লক → উপকেন্দ্র → ANM/ASHA`. Her direct reports are **ANMs**.

---

## What is the same as CMHO, and what is different

The BMHO uses the **exact same endpoints** (`/admin/stats`, `/admin/district`, `/readiness/summary`,
`/admin/workers`, `/admin/reports`) — the server scopes every one of them to her subtree
automatically. So the *data shape* is identical to the CMHO spec; read that file's "Real data
available" section.

The **difference is emphasis**, and it is real:

| | CMHO | BMHO |
|---|---|---|
| Top of Overview | District escalations, MDSR/CDR | **Her ANMs and ASHAs**, by name |
| Geography line | `জেলা → ব্লক → উপকেন্দ্র` | `ব্লক → উপকেন্দ্র → ANM/ASHA` |
| District tab title | `জেলা বিশ্লেষণ` | `ব্লক বিশ্লেষণ` |
| Ranking table | Blocks, then BMHOs | **ANMs**, then ASHAs |
| Supply view | District heatmap, block columns | **Her sub-centres**, ANM/ASHA rows |
| Mental model | "Which block is failing?" | "Which of *my* people needs help?" |

Because her `team[]` is ANMs and her `blocks[]` is usually just her own block, the district
analytics feel more personal — the ranked list is people she can call, not blocks she reports on.

---

## Screens

### 1 · Overview — *"who on my team needs me today"*

1. **Header** — `BMHO প্যানেল`, name (`Dr. Arnab Ghosh`), avatar, notification bell.
2. **Escalations (lead)** — same card stack as CMHO, but every entry is *her* people:
   - 🩸 supply gaps in her sub-centres (readiness `critical[]`)
   - ⚫ maternal / infant deaths in her block (MDSR/CDR — she initiates, CMHO reviews)
   - 🚑 stranded referrals, by patient name
   - 🔇 silent ASHAs under her, by name and sub-centre
   - ❔ `খবর নেই (n)` — her people who have not reported supplies
3. **Risk donut** — her block's RED / YELLOW / GREEN.
4. **Four stat tiles** — `totalWorkers` (her ANMs+ASHAs) · `totalPatients` · `totalReports` · `redReports`.
5. **Module strip** — NCD high-risk, TB on treatment, open referrals, pending CRS.

### 2 · Block analytics

Title `ব্লক বিশ্লেষণ`, subtitle `BMHO · গত 12 মাস`, `3 মাস / 12 মাস` toggle, PDF export.
Same HMIS indicator grid and rules as CMHO (§2). Ranked table is **`ANM অনুযায়ী পারফরম্যান্স`**
first, then **`ASHA অনুযায়ী পারফরম্যান্স`** — both from `team[]`/`blocks[]`, worst first, each row
drilling to a callable person.

### 3 · Supply & Readiness

Title `ওষুধ ও প্রস্তুতি`, subtitle `BMHO · ব্লক → উপকেন্দ্র`. Same three-slice coverage donut, same
critical-gaps panel with names. The **heatmap columns are her sub-centres** (not blocks), rows are
supplies critical-first. Same grey-is-not-green rule. This is the screen where she spots that Kolkata
sub-centre is out of Oxytocin and moves a stock transfer *today*.

### 4 · Workers · 5 · Reports · 6 · Settings
Same as CMHO. Worker cards show ANM/ASHA role chips; `redCount` red when > 0; call button.
Settings includes the **alert test** — a BMHO especially needs to confirm push works on her handset,
because she is the first rung of the escalation chain.

---

## Stitch AI prompts

> Paste the **§6 preamble** from `PANEL_DESIGN_SYSTEM.md` first.

### Prompt A — Overview

```
Design the home screen of a BLOCK health officer's (BMHO) mobile panel. 720x1600 phone.
This officer manages the ANMs and ASHAs of ONE block and is the first person a medical
emergency alert reaches — so the screen is about HER people, not district statistics.

TOP: header "BMHO প্যানেল" 24px bold, name "Dr. Arnab Ghosh (BMHO)" beneath in 15px grey,
circular avatar left, notification bell with red unread badge right.

THEN the urgent section "জরুরি — এখনই দেখুন" in red 13px semibold with a red "!" icon, and a
vertical stack of alert cards, most severe first, each white with a soft coloured left-tint,
radius 20, chevron on the right:
  1. RED, medicine icon: "প্রাণরক্ষাকারী ওষুধ/যন্ত্র নেই (1)" then 13px "Inj. Oxytocin — Kolkata
     উপকেন্দ্রে নেই" then grey "3 জন কোনও খবর দেয়নি".
  2. AMBER, ambulance icon: "1 টি রেফারেল আটকে আছে" with a patient name and "9 দিন".
  3. TEAL, muted-person icon: "2 জন ASHA ৩০ দিন নিষ্ক্রিয়" listing "Puja · Kolkata",
     "affan das · Newtown".

BELOW: a white card with a RED/YELLOW/GREEN donut and legend for this block's reports.

THEN a 2x2 grid of soft stat tiles: "4 মোট ASHA", "8 মোট রোগী", "36 মোট রিপোর্ট",
"25 জরুরি (RED)" — white, radius 16, pastel icon chip, big purple number (red for the RED tile),
12px grey caption.

Bottom nav, 5 icons, active in a soft purple pill, red badge on analytics.
Calm, warm, premium, purple-on-sage-green. NOT a corporate console.
```

### Prompt B — Block analytics

```
Design a BLOCK health analytics screen (BMHO). 720x1600 phone. Identical visual system to a
district analytics screen, but scoped to one block and its people.

HEADER: "ব্লক বিশ্লেষণ" 24px bold; grey "BMHO · গত 12 মাস"; a PDF button and a segmented
"3 মাস | 12 মাস" pill (active segment filled purple #791C87, white text) on the right.

"HMIS মূল সূচক" — 2-column grid of white metric tiles (radius 16). Each: pastel icon chip,
28px value, 12px Bengali caption, and a top-right delta arrow coloured by MEANING (green when
the change is good, red when bad). Tiles: "2 · প্রসূতি নথিভুক্ত" (↑ green),
"100.0% · ১ম ত্রৈমাসিকে ANC", "50.0% (n=2) · 8+ ANC ভিজিট", "1 · উচ্চ ঝুঁকি প্রসূতি" (↑ red),
"— · প্রাতিষ্ঠানিক প্রসব", "— · সিজার", "11.1% · টিকা কভারেজ",
"13 · টিকা বাকি (Overdue)" with a tappable red "এখন ›" chip.
The "—" tiles mean "no data yet" and must look calm and deliberate, never broken.

THEN a white card "ANM অনুযায়ী পারফরম্যান্স" with grey subtitle "কে পিছিয়ে আছে — সেটাই এখানে
দেখা যায়". A ranked list, worst first: each row has the ANM's name (15px semibold), a thin
progress bar, and small grey stat chips "4 ASHA · 0 জন্ম · 11% টিকা · 36 রিপোর্ট".

THEN the same card titled "ASHA অনুযায়ী পারফরম্যান্স" listing individual ASHAs the same way.

Bottom nav. Airy, premium, purple-on-sage-green.
```

### Prompt C — Supply & readiness

```
Use the same medical-supply readiness layout as the district (CMHO) supply screen — coverage
donut with three segments (green "খবর দিয়েছে" / amber "পুরোনো খবর" / grey "কখনও খবর দেয়নি"),
a red critical-gaps panel listing missing life-saving items with the NAMES and sub-centres of who
is out, and a horizontally-scrolling heatmap grid.

Two differences for the BMHO version:
  - HEADER subtitle reads "BMHO · ব্লক → উপকেন্দ্র".
  - The heatmap COLUMNS are her sub-centres (e.g. "Kolkata উপকেন্দ্র", "Newtown উপকেন্দ্র"),
    not blocks. Rows are supplies, critical ones first (BP মেশিন, অ্যাম্বুলেন্স, Inj. MgSO4,
    Inj. Oxytocin) with a thin red bar beside their label.

Cell colours: red #EF4444 নেই, amber #FACC15 কম, green #22C55E আছে, light grey খবর নেই.
Grey must NEVER be green — an unreported sub-centre is not a stocked one. Four-swatch legend
beneath the grid. Premium, purple-on-sage-green, the heatmap is the hero.
```
