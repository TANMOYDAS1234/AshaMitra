# ANM Panel — Design Spec & Stitch Prompts

> Read `PANEL_DESIGN_SYSTEM.md` first. Paste its **§6 preamble** before every prompt below.

---

## Who this is for

The **Auxiliary Nurse Midwife** runs a sub-centre and the handful of ASHAs under it. She is the
**lowest supervisory rung and the most hands-on** — she runs the sub-centre clinic herself, gives
the injections, keeps the cold chain, *and* supervises 4–6 ASHAs. She is not an administrator; she is
a frontline nurse who also happens to have a team.

So her panel is the bridge between the worker app and the officer panels. It must feel almost as
immediate as the ASHA's own home screen — small team, first names, no district abstractions — while
still giving her the supervisor tools: whose ANC visits are slipping, who has gone quiet, what her
sub-centre is running low on.

She also, uniquely, **reports supplies herself** (MgSO4, Oxytocin, Hb strips, Td vaccine) *and*
reviews her ASHAs' reports. She is on both sides of the readiness pulse.

**The screen must answer: _which of my few ASHAs, and which of my mothers, needs me this week?_**

Scope: `উপকেন্দ্র → ASHA`. Her direct reports are **ASHAs**.

---

## What is the same, and what is different

Same endpoints as CMHO/BMHO, auto-scoped to her small subtree. Read the CMHO file's
"Real data available" section for field shapes. Her `team[]` is her individual ASHAs; her
`blocks[]` collapses to essentially her own area, so the *block ranking is less useful* and the
**ASHA ranking is the heart of it**.

| | BMHO | ANM |
|---|---|---|
| Team size | dozens (ANMs + all their ASHAs) | a handful (4–6 ASHAs) |
| Geography line | `ব্লক → উপকেন্দ্র → ANM/ASHA` | `উপকেন্দ্র → ASHA` |
| Analytics title | `ব্লক বিশ্লেষণ` | `উপকেন্দ্র বিশ্লেষণ` |
| Ranking | ANMs, then ASHAs | **ASHAs only** |
| Readiness role | reviews her sub-centres | **fills the check herself AND reviews ASHAs** |
| Feel | supervisor dashboard | frontline nurse + small team |

Because the team is small, prefer **names and faces over bars and percentages**. A 4-row ASHA list
with photos beats a ranked chart. This is the panel closest in spirit to the ASHA app.

---

## Screens

### 1 · Overview — *"my sub-centre this week"*

1. **Header** — `ANM প্যানেল`, name (`Arpita Das`), avatar, notification bell.
2. **Escalations (lead)** — scoped to her ASHAs and her sub-centre:
   - 🩸 supplies *she* is out of (readiness `critical[]` — she is a reporter here)
   - 🚑 stranded referrals from her ASHAs, by patient name
   - 🔇 her silent ASHAs, by name
   - ❔ her own overdue readiness check (prompt her to fill it — she is the reporter)
3. **My ASHAs** — a compact list of her 4–6 ASHAs with photo/initial, name, `reportCount`,
   `redCount` (red if > 0), and a call button. This is the emotional centre of her panel.
4. **Risk donut + stat tiles** — her sub-centre's RED/YELLOW/GREEN and the four totals.

### 2 · Sub-centre analytics

Title `উপকেন্দ্র বিশ্লেষণ`, subtitle `ANM · গত 12 মাস`, `3 মাস / 12 মাস` toggle, PDF export.
Same HMIS indicator grid and rules. The ranked table is **`ASHA অনুযায়ী পারফরম্যান্স`** only —
worst first, each row a callable person with her key numbers.

### 3 · Supply & Readiness — *she is on both sides*

Two modes, both reachable here:
- **Fill my check** (`GET /readiness/catalogue` → `POST /readiness/report`) — her own sub-centre's
  MgSO4, Oxytocin, Hb strips, Td vaccine, etc. The fast 3-tap form. Marking a critical item `নেই`
  pushes straight to her BMHO and CMHO.
- **My ASHAs' readiness** (`GET /readiness/summary`) — the small rollup of her ASHAs, same
  three-slice coverage donut and grey-is-not-green rule, but a short list rather than a big heatmap.

Title `ওষুধ ও প্রস্তুতি`, subtitle `ANM · উপকেন্দ্র → ASHA`.

### 4 · Workers · 5 · Reports · 6 · Settings
Same components, small scale. Workers are her ASHAs. Settings has the alert test.

---

## Stitch AI prompts

> Paste the **§6 preamble** from `PANEL_DESIGN_SYSTEM.md` first.

### Prompt A — Overview

```
Design the home screen of an ANM's (Auxiliary Nurse Midwife) mobile panel. 720x1600 phone.
An ANM runs a sub-centre clinic AND supervises just 4-6 ASHAs — she is a hands-on frontline
nurse, not an administrator. This screen should feel warm and personal, closer to a worker's
home screen than to a corporate dashboard, while still surfacing what needs her attention.

TOP: header "ANM প্যানেল" 24px bold, name "Arpita Das" beneath in 15px grey, a circular avatar
(with a real photo feel) on the left, notification bell with a red badge on the right.

THEN a compact urgent section "জরুরি — এখনই দেখুন" in red 13px semibold with a red "!" icon,
and 1-3 alert cards (white, soft coloured left-tint, radius 20, chevron):
  - AMBER, box icon: "আপনার ওষুধের খবর ৭ দিন পুরোনো — এখন জানান" (a nudge to fill her own check).
  - TEAL, muted-person icon: "1 জন ASHA ৩০ দিন নিষ্ক্রিয়" with "Puja · Kolkata".

THEN — the heart of the screen — a white card titled "আমার ASHA দল" listing her ASHAs as rows.
Each row: a circular avatar/initial, the ASHA's name in 15px semibold, small grey stats
"36 রিপোর্ট · 25 RED" (the RED number in red if above zero), and a small round purple call button
on the right. Show 4 rows: Sayantani Das, Puja, Puja, affan das.

BELOW: a white card with a small RED/YELLOW/GREEN donut and legend, and a 2x2 grid of soft stat
tiles ("4 মোট ASHA", "8 মোট রোগী", "36 মোট রিপোর্ট", "25 জরুরি (RED)").

Bottom nav, 5 icons, active in a soft purple pill, red badge on analytics.
Warm, human, premium, purple-on-sage-green. This is the friendliest of the officer panels.
```

### Prompt B — Sub-centre analytics

```
Design a SUB-CENTRE analytics screen (ANM). 720x1600 phone. Same visual system as the block/
district analytics, but small and personal — one sub-centre and a handful of ASHAs.

HEADER: "উপকেন্দ্র বিশ্লেষণ" 24px bold; grey "ANM · গত 12 মাস"; PDF button and a
"3 মাস | 12 মাস" segmented pill (active filled purple #791C87, white text).

"HMIS মূল সূচক" — 2-column grid of white metric tiles (radius 16): pastel icon chip, 28px value,
12px Bengali caption, meaning-coloured delta arrow. Tiles: "2 · প্রসূতি নথিভুক্ত" (↑ green),
"100.0% · ১ম ত্রৈমাসিকে ANC", "50.0% (n=2) · 8+ ANC ভিজিট", "1 · উচ্চ ঝুঁকি প্রসূতি" (↑ red),
"— · প্রাতিষ্ঠানিক প্রসব", "11.1% · টিকা কভারেজ", "13 · টিকা বাকি (Overdue)" (tappable red "এখন ›"
chip). The "—" tiles are a calm, deliberate "no data yet" state, never broken-looking.

THEN a single white card "ASHA অনুযায়ী পারফরম্যান্স" with grey subtitle "কে পিছিয়ে আছে —
সেটাই এখানে দেখা যায়". A short ranked list (4-6 rows), worst first: each row = ASHA name in
15px semibold, a thin progress bar, and small grey stat chips "0 জন্ম · 11% টিকা · 36 রিপোর্ট".

Bottom nav. Airy, premium, purple-on-sage-green.
```

### Prompt C — Supply & readiness (the ANM fills it herself)

```
Design a medical-supply readiness screen for an ANM. 720x1600 phone. Unlike higher officers, the
ANM both FILLS IN her own sub-centre's supply check AND reviews her ASHAs. Show two parts.

HEADER: back arrow, "ওষুধ ও প্রস্তুতি" 24px bold, grey subtitle "ANM · উপকেন্দ্র → ASHA".

PART 1 — "আমার উপকেন্দ্রের খবর দিন" (fill my check). A fast form: a list of supply rows, each with
the supply name on the left (Bengali, with critical ones like "Inj. MgSO4 (খিঁচুনি/এক্লাম্পসিয়া)"
and "Inj. Oxytocin" carrying a thin red bar), and on the right THREE pill buttons in a row:
"আছে" (green), "কম" (amber), "নেই" (red) — the selected one filled solid, the others as light
tinted outlines. At the bottom, a full-width purple "পাঠিয়ে দিন" button, and above it a small red
warning line: "2 টি জরুরি জিনিস নেই — পাঠালে সঙ্গে সঙ্গে আপনার উপরের অফিসারের ফোনে খবর যাবে।"

PART 2 — "আমার ASHA দলের অবস্থা" (my ASHAs' readiness). A small three-segment coverage donut
(green খবর দিয়েছে / amber পুরোনো খবর / grey কখনও খবর দেয়নি) and a short list of ASHAs, each with a
coloured status dot and a line like "সব ঠিক আছে" or "কখনও খবর দেয়নি". Grey means unknown, NEVER
green.

Clean, warm, premium, purple-on-sage-green.
```
