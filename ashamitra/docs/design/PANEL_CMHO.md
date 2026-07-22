# CMHO Panel — Design Spec & Stitch Prompts

> Read `PANEL_DESIGN_SYSTEM.md` first. Paste its **§6 preamble** before every prompt below.

---

## Who this is for

The **Chief Medical Officer of Health** is the head of the public health system for an entire
district. Her official remit spans fourteen areas: administration of every facility (DH, SDH,
BPHC, PHC, HWC, SC), human resources, drug and logistics, immunization, **all National Health
Programmes**, disease surveillance, outbreak response, budget, monitoring and evaluation, health
data, training, disaster response, hospital inspection, and review meetings.

She opens this app for about ninety seconds, standing up, between meetings.

**The screen must answer one question: _what must I fix before tonight?_**

### What this app can honestly serve — and what it cannot

This is a **field-worker app**. It sees what ASHAs record. Designing the panel as if it were a
district ERP would produce screens that can never be filled.

| CMHO responsibility | In this app? |
|---|---|
| Maternal health (ANC/PNC, high-risk, MDSR) | ✅ full |
| Child health + immunization | ✅ full |
| **NTEP (TB)** — DOTS, adherence, Nikshay | ✅ `TbCase` |
| **NCD** — diabetes, HTN, cancers (CBAC) | ✅ `NcdCbac` |
| **Family Planning** — methods, unmet need | ✅ `EligibleCouple` |
| **CRS** — birth/death registration | ✅ `VitalEvent` |
| Drug & logistics | ✅ `MedicineStock` + readiness pulse |
| Vector-borne (malaria, dengue), leprosy, blindness | ❌ **no data** — triage has 7 RCH case types, no fever pathway |
| Disease surveillance / outbreak / RRT | ❌ no data |
| HR (postings, leave, salary), budget, training records | ❌ not a field-app function |
| Facility inspection, OT/labour-room QA | ❌ no facility model exists |

**Do not design a screen for a row marked ❌.** An empty "Malaria: 0" tile implies zero cases in a
district that has simply never been asked — the same class of lie as rendering a null percentage
as `0%`. The programmes screen ends with a visible note naming what is absent, so a missing
programme cannot read as a healthy one.

Scope: `জেলা → ব্লক → উপকেন্দ্র`. Her direct reports are **BMHOs**.

---

## Real data available (do not design beyond this)

### `GET /api/admin/stats`
`totalWorkers · totalPatients · totalReports · redReports · yellowReports · greenReports`
`modules.{ncdScreened, ncdHighRisk, tbPresumptive, tbOnTreatment, medLowStock, vitalPendingCrs, referralOpen}`

### `GET /api/admin/district?months=3|12`
**`indicators`** (and a matching **`prev`** for the previous window, for deltas):
| Field | Note |
|---|---|
| `ashas` | count |
| `pregnanciesRegistered` | count |
| `ancFirstTrimesterPct` | **nullable** |
| `anc4PlusPct` | **nullable** |
| `highRiskPregnancies` | count |
| `births` | count |
| `institutionalDeliveryPct` | **nullable** |
| `cSectionPct` | **nullable** — no "good" direction |
| `sbaAttendedPct` | **nullable** |
| `lbwPct` + `lbwWeighed` | **nullable**; `lbwWeighed` is the denominator — show it |
| `immunizationCoveragePct` | **nullable** |
| `immunizationDefaulters` | count |
| `pncVisits` | count |
| `maternalDeaths` | **↑ is RED** |
| `infantDeaths` | **↑ is RED** |
| `referralClosurePct` | **nullable** |
| `openReferrals` | count |

**`blocks[]`** — `block · ashas · births · institutional · caesarean · lbw · lbwWeighed ·
maternalDeaths · infantDeaths · vacDue · vacDone · vacOverdue · reports · red ·
institutionalPct · lbwPct · immunizationPct`

**`team[]`** — her BMHOs: `id · name · role · ashas · births · reports · red · institutionalPct ·
lbwPct · immunizationPct · …` (same shape as blocks)

**`defaulters[]`** — `patientName · patientMobile · label · daysOverdue · asha · block`
plus `defaultersTotal`

**`alerts`** — `maternalDeaths[] · infantDeaths[] · stockouts[] · silentAshas[] · overdueReferrals[]`

### `GET /api/readiness/summary`
`coverage.{expected, reported, stale, never}` · `critical[].{code, bn, count, places[]}` ·
`low[]` · `blocks[].{block, criticalOut, low, reported, stale, never, units[]}` ·
`items[].{code, bn, cat, critical}` · `matrix[].{block, cells{code → {ok,low,out}}}`

### `GET /api/admin/workers` · `GET /api/admin/reports`
Worker: `name · phone · role · block · subCentre · teamSize · patientCount · reportCount · redCount · isActive`
Report: `patientName · caseLabel · finalBand · riskScore · dangerSigns[] · suspectedConditions[] ·
facilityType · createdAt`

> **There are no map coordinates. There is no time-series.** `prev` gives you exactly one
> comparison point. Anything else on a chart is fabricated.

---

## Screens

### 1 · Overview — *"what must I fix before tonight"*

**Order is the design.** Do not reorder these for visual balance.

1. **Header** — `CMHO প্যানেল`, name, avatar, notification bell with unread count.
2. **Escalations (leads, always)** — a stacked list, worst first:
   - 🩸 **Missing life-saving supply** — `critical[]` from readiness. *"FRU-তে রক্ত নেই — Kalyani"*.
     Red. Tappable → supply screen. **This is the only card on the screen naming something still
     preventable.**
   - ⚫ **Maternal deaths** (`alerts.maternalDeaths`) — MDSR required.
   - ⚫ **Infant deaths** (`alerts.infantDeaths`) — CDR required.
   - 🚑 **Stranded referrals** (`alerts.overdueReferrals`) — open > 7 days, by name.
   - 🔇 **Silent ASHAs** (`alerts.silentAshas`) — zero-reporting, by name and block.
   - ❔ **"খবর নেই (n)"** — readiness `coverage.never + stale`. *Rendered as loudly as a failure.*
3. **Live band strip** — `redReports / yellowReports / greenReports` as a donut + counts.
4. **Four stat tiles** — `totalWorkers · totalPatients · totalReports · redReports`.
5. **Module strip** — NCD high-risk, TB on treatment, open referrals, pending CRS registrations.

> If every escalation is empty **and** readiness is fully reported, show a single calm green
> all-clear card. If readiness is *unreported*, you may **not** show all-clear.

---

### 2 · District — HMIS analytics

1. **Header** — `জেলা বিশ্লেষণ`, subtitle `CMHO · গত 12 মাস`, period toggle **3 মাস / 12 মাস**,
   PDF export button.
2. **Escalation strip** (same as Overview, condensed).
3. **HMIS মূল সূচক** — a 2-column grid of indicator tiles. Each tile:
   - big value (or **`—`**), Bengali label, icon chip in `primarySoft`
   - delta vs `prev` with **meaning-coloured** arrow (see rule 6)
   - `lbwPct` tile must show `n = lbwWeighed`
   - tappable where a drill-down exists (`immunizationDefaulters` → the 13 names)
4. **Risk donut** — RED / YELLOW / GREEN split, with counts.
5. **ব্লক অনুযায়ী পারফরম্যান্স** — ranked block table, *worst first*. Per row: block name,
   `ashas`, `births`, `immunizationPct`, `reports`, a thin progress bar, red badge for
   `maternalDeaths > 0`.
6. **BMHO অনুযায়ী পারফরম্যান্স** — same, for `team[]`.
7. **Defaulters drill-down** (sheet) — grouped by ASHA, worst first, `patientName · label ·
   daysOverdue · tap-to-call`.

---

### 3 · Supply & Readiness — *the screen that saves lives*

Reached from the escalation card, and always reachable even when green.

1. **Header** — `ওষুধ ও প্রস্তুতি`, subtitle `CMHO · জেলা → ব্লক → উপকেন্দ্র`.
2. **Coverage donut** — **three** slices: reported (green) / stale (amber) / never (grey).
   Two slices would let a district where nobody reports look identical to a healthy one.
3. **প্রাণরক্ষাকারী জিনিস নেই** — each missing critical item, count, and **the names and blocks**.
4. **Heatmap: ব্লক × ওষুধ/যন্ত্র** — rows = supplies (critical first: MgSO4, Oxytocin, BP মেশিন,
   অ্যাম্বুলেন্স, FRU রক্ত), columns = blocks. Cell: red = নেই, amber = কম, green = আছে,
   **grey = খবর নেই**. Legend mandatory. Horizontally scrollable inside its own card.
5. **Block bars** — one stacked bar per block, worst on top.
6. **Drill-down** — tap a block → the people inside, each with state
   (`fresh` / `stale (n দিন আগে)` / `কখনও খবর দেয়নি`).

---

### 3b · Health Programmes — *the other six sevenths*

`GET /api/admin/programmes?months=3|12` → `programmes[]`, each:
`key · name · icon · headline[{label, value (nullable), suffix, alarm}] ·
actions[{title, severity: high|medium|none, rows[{name, detail, village, block, mobile}]}] ·
blocks[{block, total, flagged}]`

Five programme cards, collapsed by default, each expanding to its action lists:

| Card | Headline | What it makes her do |
|---|---|---|
| **যক্ষ্মা (NTEP)** | on treatment · presumptive · **doses missed** · **not in Nikshay** | Missed doses = drug resistance forming. No Nikshay ID = invisible to the state and drugs not requisitioned. Both listed by name. |
| **NCD স্ক্রিনিং** | screened · **CBAC ≥ 4** · known diabetes · known HTN | High-risk people needing confirmatory testing; referred-with-no-follow-up-date. |
| **পরিবার পরিকল্পনা** | eligible couples · adopted · **unmet need** · coverage % | Unmet need is *the* FP indicator. Prioritised by youngest child < 1 year — a short birth interval is the highest-risk next pregnancy. |
| **জন্ম-মৃত্যু নিবন্ধন (CRS)** | births · deaths · **unregistered** · registered % | Deaths needing MDSR/CDR; unregistered events (a child with no legal identity). |
| **ওষুধ ও সরবরাহ** | lines below threshold | Points at the readiness pulse, which is the better live signal. |

Rules specific to this screen:
- Every action row ends in a **phone icon**. Naming a person is pointless if you can't reach them.
- An action with **zero rows is not rendered** — an empty "0 people" list trains the eye to skip.
  A programme with no live actions shows a single calm green "এই মুহূর্তে কিছু করার নেই".
- A `null` headline (e.g. FP coverage with no eligible couples) is a grey **`—`**, never `0%`.
- The screen **ends with the absence note** (see §"What this app can honestly serve").

---

### 4 · Workers · 5 · Reports · 6 · Settings
Standard list + filter + detail. Worker card: avatar, name, role chip (`BMHO`), block, `teamSize`,
`reportCount`, `redCount` (red if > 0), call button. Report card: band stripe (RED/YELLOW/GREEN),
patient name, case label, ASHA, timestamp, danger signs as chips.
Settings: profile, language, **alert test**, logout.

---

## Stitch AI prompts

> Paste the **§6 preamble** from `PANEL_DESIGN_SYSTEM.md` first, then one of these.

### Prompt A — Overview

```
Design the home screen of a district health officer's (CMHO) mobile panel. 720x1600 phone.

TOP: A greeting header — "CMHO প্যানেল" in 24px bold, the officer's name "Dr. Sudipta Roy"
beneath in 15px secondary grey, a circular avatar on the left, and a notification bell with
a small red unread badge on the right.

THEN — and this is the most important part of the screen — an "urgent, act now" section
titled "জরুরি — এখনই দেখুন (3)" in red 13px semibold with a red exclamation icon.
Below it, a vertical stack of alert cards, most severe first. Each card is white with a
soft coloured left-tint, radius 20, and a chevron:

  1. RED card, medicine icon: "প্রাণরক্ষাকারী ওষুধ/যন্ত্র নেই (2)"
     with two lines beneath in 13px: "Inj. MgSO4 — 3 জায়গায় নেই (Kolkata)" and
     "FRU-তে রক্ত নেই — 1 জায়গায় (Kalyani)".
     Then a smaller grey line: "4 জন কোনও খবর দেয়নি — 'খবর নেই' মানে 'ঠিক আছে' নয়".
  2. RED card, female icon: "1 টি মাতৃমৃত্যু" / "ডেথ রিভিউ (MDSR) দরকার".
  3. AMBER card, ambulance icon: "2 টি রেফারেল আটকে আছে" with patient names and days.
  4. TEAL card, muted-person icon: "2 জন ASHA ৩০ দিন নিষ্ক্রিয়" listing "Puja · Kolkata"
     and "affan das · Newtown".

BELOW the fold: a white card with a donut chart splitting reports into RED (25) /
YELLOW (7) / GREEN (0), with a legend to its right.

THEN a 2x2 grid of soft stat tiles: "4 মোট ASHA", "8 মোট রোগী", "36 মোট রিপোর্ট",
"25 জরুরি (RED)". Each tile: white, radius 16, a pastel icon chip top-left, a large
number in brand purple (or red for the RED tile), a 12px grey Bengali caption.

Bottom navigation with 5 icons (dashboard, analytics, people, bar-chart, settings),
labels hidden, the active one in a soft purple pill, and a red count badge on analytics.

Calm, premium, generous whitespace. Purple-on-sage-green. NOT a corporate admin console.
```

### Prompt B — District analytics

```
Design a district health analytics screen (CMHO) for a 720x1600 phone.

HEADER: "জেলা বিশ্লেষণ" 24px bold; beneath, small grey "CMHO · গত 12 মাস".
On the right: a circular PDF-export button, and a segmented pill toggle "3 মাস | 12 মাস"
with the active segment filled brand purple #791C87 and white text.

SECTION "HMIS মূল সূচক" with a 12px grey subtitle "সরকারি HMIS ফর্মুলা অনুযায়ী".
Below it, a 2-column grid of metric tiles. Each tile is white, radius 16, soft shadow, and
contains: a pastel rounded icon chip (top-left), a large 28px value, a 12px Bengali caption,
and — top-right — a small delta like "↑2.0" in GREEN when the change is good or "↑1" in RED
when the change is bad. Show these tiles:

  "2 · প্রসূতি নথিভুক্ত" (↑2.0 green)
  "100.0% · ১ম ত্রৈমাসিকে ANC"
  "50.0% (n=2) · 8+ ANC ভিজিট"      ← note the sample size shown in grey
  "1 · উচ্চ ঝুঁকি প্রসূতি" (↑1 red)
  "— · প্রাতিষ্ঠানিক প্রসব"           ← an em-dash, NOT 0%. Render the dash in light grey.
  "— · সিজার"
  "— · কম ওজনের শিশু (<২.৫ কেজি)"
  "11.1% · টিকা কভারেজ"
  "13 · টিকা বাকি (Overdue)"  with a small red "এখন ›" chip meaning it is tappable
  "100.0% · রেফারেল সম্পন্ন"

CRITICAL: the "—" tiles are a real, designed state meaning "no data yet" — they must look
deliberate and calm, not broken or empty.

THEN a white card "ব্লক অনুযায়ী পারফরম্যান্স" with grey subtitle "কে পিছিয়ে আছে — সেটাই এখানে
দেখা যায়". Inside, a ranked list, worst first. Each row: block name in 15px semibold, then a
thin full-width progress bar, then a row of small grey stat chips with icons —
"3 ASHA · 0 জন্ম · 11% টিকা · 36 রিপোর্ট". A red dot badge on any block with a maternal death.

THEN the same card pattern titled "BMHO অনুযায়ী পারফরম্যান্স".

Bottom nav as before. Airy, premium, purple-on-sage-green.
```

### Prompt C — Supply & readiness (the heatmap)

```
Design a medical-supply readiness screen for a district health officer. 720x1600 phone.

HEADER: back arrow, title "ওষুধ ও প্রস্তুতি" 24px bold, grey subtitle
"CMHO · জেলা → ব্লক → উপকেন্দ্র", refresh icon on the right.

CARD 1 — coverage. On the left a donut chart with THREE segments: green "খবর দিয়েছে",
amber "পুরোনো খবর", grey "কখনও খবর দেয়নি", with "1/5" and the caption "খবর দিয়েছে" in its
centre. On the right, two stacked stats: "2 · জরুরি ঘাটতি" in red, and "4 · খবর নেই" in amber.

CARD 2 — a red-tinted panel "প্রাণরক্ষাকারী জিনিস নেই" with the grey subtitle
"একদিনে ঠিক করা যায় — এবং করলে জীবন বাঁচে". Inside, rows like:
  [red count pill "3"]  Inj. MgSO4 (খিঁচুনি/এক্লাম্পসিয়া)
      Arpita Das · Kolkata
      Sayantani Das · Kolkata
Names and places matter more than the number — make them legible, not fine print.

CARD 3 — THE HEATMAP, titled "ব্লক × ওষুধ/যন্ত্র", grey subtitle "লাল = নেই · ধূসর = খবরই আসেনি".
A grid: the LEFT column is a fixed list of supply names (Bengali, 12px), the grid to its right
scrolls horizontally with one column per block (Kolkata, Kalyani, Newtown, HQ). Every cell is a
44x30 rounded square:
    red #EF4444   = নেই   (with a small white count number if >1)
    amber #FACC15 = কম
    green #22C55E = আছে
    light grey    = খবর নেই     ← MUST be grey, never green
Critical supplies (BP মেশিন, অ্যাম্বুলেন্স, Inj. MgSO4, Inj. Oxytocin, FRU-তে রক্ত) come first and
carry a thin red vertical bar to the left of their label. Beneath the grid, a legend with four
small colour swatches: নেই / কম / আছে / খবর নেই.

CARD 4 — "ব্লক অনুযায়ী অবস্থা", worst first. Per block: name, then a thin horizontal stacked bar
segmented red/amber/green/grey by proportion, with a small red "N নেই" label on the right.

THEN expandable block cards: "Kalyani" with red pills "1 জরুরি ঘাটতি", tapping reveals the people
inside — a coloured status dot, name · sub-centre, and a status line like "কখনও খবর দেয়নি" or
"3 দিন আগের খবর".

Clean, premium, purple-on-sage-green. The heatmap is the hero — give it room to breathe.
```

### Prompt D — Health Programmes

```
Design a "National Health Programmes" screen for a district health officer (CMHO).
720x1600 phone. This is where she checks every government programme she runs, other
than maternal/child health which has its own screen.

HEADER: back arrow, title "স্বাস্থ্য কর্মসূচি" 24px bold, grey subtitle
"CMHO · জেলা · জাতীয় কর্মসূচির অবস্থা", refresh icon right. Beneath, right-aligned, a
small segmented pill "3 মাস | 12 মাস" (active filled purple #791C87, white text).

THEN a vertical stack of five collapsible PROGRAMME CARDS. Each is white, radius 20,
soft shadow. A card with urgent work has a thin red border and a red count badge.

Collapsed card layout: a pastel rounded icon chip on the left, the programme name in
17px semibold, a red count badge if urgent, a chevron; then BELOW that, a row of 3-4
headline stats — each a large 20px number above a 12px grey Bengali label. A stat that
is alarming shows its number in red; a stat with no data shows a grey em-dash "—".

  CARD 1 "যক্ষ্মা (NTEP)" — RED BORDER, badge "5"
     stats: "12 চিকিৎসাধীন" | "3 সন্দেহভাজন" | "4 ডোজ বাদ পড়েছে" (RED) |
            "1 Nikshay-এ নেই" (RED)
     EXPANDED, showing two action groups. Each group: a thin coloured vertical bar,
     a bold coloured title, a count on the right, then rows of named people:
       ▌ডোজ বাদ পড়েছে — চিকিৎসা ভেঙে যাচ্ছে          4
           Rahim Sheikh
           4 ডোজ বাদ · Ghosalpur · Kolkata            [phone icon]
           Anima Das
           2 ডোজ বাদ · Baruipara · Kalyani            [phone icon]
       ▌Nikshay ID নেই — রাজ্যের হিসাবে নেই            1
           Sabina Bibi
           Pulmonary TB · Newtown                     [phone icon]
     Then a small "ব্লক অনুযায়ী" list: "Kolkata 3/7", "Kalyani 1/4" (flagged/total, red).

  CARD 2 "NCD স্ক্রিনিং" — collapsed
     stats: "148 স্ক্রিন করা হয়েছে" | "22 উচ্চ ঝুঁকি (CBAC ≥ 4)" (RED) |
            "9 জানা ডায়াবেটিস" | "14 জানা উচ্চ রক্তচাপ"

  CARD 3 "পরিবার পরিকল্পনা" — collapsed
     stats: "64 যোগ্য দম্পতি" | "41 পদ্ধতি নিয়েছেন" | "23 পদ্ধতি নেননি" (RED) |
            "64.1% কভারেজ"

  CARD 4 "জন্ম-মৃত্যু নিবন্ধন (CRS)" — collapsed
     stats: "18 জন্ম" | "3 মৃত্যু" | "5 নিবন্ধন বাকি" (RED) | "76.2% নিবন্ধিত"

  CARD 5 "ওষুধ ও সরবরাহ" — collapsed, calm
     stats: "0 কম স্টক লাইন"; expanded shows a green line "এই মুহূর্তে কিছু করার নেই"
     with a check-circle icon.

Icons: TB = virus, NCD = heart-monitor, family planning = family, CRS = verified-person,
drugs = pill.

AT THE BOTTOM, a quiet grey rounded box (NOT a white card, no shadow) with a small info
icon and 12px grey text: "এখানে শুধু সেই কর্মসূচি দেখানো হয় যেগুলোর তথ্য ASHA কর্মীরা এই
অ্যাপে তোলেন। ম্যালেরিয়া/ডেঙ্গু সার্ভেইল্যান্স, কুষ্ঠ, অন্ধত্ব — এগুলোর তথ্য এখনও সংগ্রহ করা
হয় না, তাই দেখানো হয়নি।"
This note is deliberate and must not be removed — it stops a missing programme from
looking like a healthy one.

Calm, premium, purple-on-sage-green. The named people are the point: make them legible,
never fine print.
```
