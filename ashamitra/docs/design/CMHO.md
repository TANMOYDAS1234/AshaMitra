# CMHO Panel — Complete UI Spec & Stitch AI Prompts

Everything needed to redesign all eight CMHO screens, with a **dedicated colour
identity** distinct from the ASHA worker app.

> Companion files: `PANEL_DESIGN_SYSTEM.md` (shared tokens), `CMHO_GAP_ANALYSIS.md`
> (what exists), `PANEL_BMHO.md` / `PANEL_ANM.md` (the other panels).

---

## 1. The CMHO colour identity — "District Command"

The ASHA app is **purple on sage-green**: warm, human, community-facing. It is
held by a woman walking between houses.

The CMHO panel is a **different register of the same product**. It is read by a
district officer standing in a government office between meetings. It should feel
institutional, calm and authoritative — a command centre, not a companion.

So: **deep petrol teal on cool mist.**

### Brand — CMHO only

| Token | Hex | Use |
|---|---|---|
| `cmhoPrimary` | `#0E5A6B` | Buttons, active nav, key numbers, headers |
| `cmhoDeep` | `#08404E` | Emphasis, gradient ends, dark surfaces |
| `cmhoMid` | `#14788C` | Charts, secondary series, decorative |
| `cmhoSoft` | `#E1EFF3` | Icon chips, quiet fills, focus halos |
| `cmhoLine` | `#CBDDE3` | Card borders, dividers |

### Surfaces — CMHO only

| Token | Hex |
|---|---|
| Page gradient | `#EDF3F5 → #E5EEF2 → #F5F9FB` (topLeft → bottomRight) |
| `surface` | `#FFFFFF` |
| `surfaceMuted` | `#F1F5F7` |
| Text primary | `#14252B` (deep slate) |
| Text secondary | `#5B6B72` |
| Text light | `#94A6AD` |

### Clinical bands — IDENTICAL across every panel. Never re-themed.

| Token | Hex | Meaning |
|---|---|---|
| `emergencyRed` | `#EF4444` | RED band · missing life-saving supply · death · disease cluster |
| `warningYellow` | `#FACC15` | YELLOW band · low stock · stale report · overdue |
| `safeGreen` | `#22C55E` | GREEN band · available · all-clear |
| Unknown grey | `#CBD5DB` | **No report received** — never green |

**This is the one rule that must not bend.** A worker and her CMHO discuss the
same case; if red means one thing on her screen and another on his, the
escalation chain breaks. The brand colour may change between panels. **The safety
colours may not.**

### Deliberately no decorative accent

The ASHA app has a warm orange accent. The CMHO panel drops it. On a screen where
red, amber and green each carry clinical meaning, a fourth decorative colour
competes for the same attention and dilutes all of them. Teal + the three bands +
grey is the entire palette. Fewer colours, more meaning per colour.

### Extending to BMHO and ANM (optional)

If you want the whole hierarchy colour-coded, use a graded family — the closer to
the field, the warmer:

| Panel | Primary | Feel |
|---|---|---|
| CMHO (district) | `#0E5A6B` deep petrol | institutional |
| BMHO (block) | `#14788C` mid teal | operational |
| ANM (sub-centre) | `#0EA5B5` bright teal | close to the field |
| ASHA (worker) | `#791C87` purple | human, community |

---

## 2. Everything else stays shared

Do **not** re-invent these per panel — they are what make it one product.

**Font:** `SolaimanLipi` (Bengali + Latin, one family).

| Style | Size / Weight / Line-height |
|---|---|
| h1 | 24 / 700 / 1.25 |
| h2 | 20 / 600 / 1.30 |
| h3 | 17 / 600 / 1.35 |
| body | 15 / 400 / 1.45 |
| bodySm | 13 / 400 / 1.40 |
| label | 13 / 600 / 1.30 |
| caption | 12 / 500 / 1.30 |
| overline | 11 / 600 / 1.20 · +0.6 tracking |

**Radius:** 8 chips · 12 inputs · 16 cards · 20 hero cards · 28 sheets · 999 pills
**Shadow:** `rgba(20,37,43,0.04) blur 6 y+2` standard · `0.06 blur 12 y+4` raised
**Spacing:** 4 · 8 · 16 · 24 · 32 — page padding 16–24, card padding 14–20

**Language:** Bengali first, with the English terms workers actually use — keep in
Latin: `ASHA ANM BMHO CMHO ANC PNC BP HMIS RED YELLOW GREEN Overdue MgSO4
Oxytocin FRU ORS IFA NTEP NCD Nikshay CRS ILR RRT`

---

## 3. The seven rules — these outrank any visual preference

1. **`—` is not `0`.** The API returns `null` when a denominator is zero. Render
   an em-dash in grey. "0% institutional delivery" reads as catastrophe; the truth
   is "no births recorded yet".
2. **Grey is not green.** "Nobody reported" must never look like "all is well".
3. **Show the denominator or suppress the number.** `50.0%` from n=2 is one woman.
4. **Actions lead, totals follow.** The top of the screen answers *what must I fix
   today*, never *how many reports have we ever collected*.
5. **Names, not rates.** Every aggregate drills to people, with a phone number.
6. **Trend arrows are coloured by meaning.** ↑ immunisation = green. ↑ maternal
   deaths = red. ↑ C-section = neither (it is a range, 10–15%).
7. **Say why an alert fired.** "normal 1.3 → now 5, 3.8×". An alert that cannot be
   audited is one she will stop trusting.

---

## 4. Stitch preamble — paste before EVERY prompt below

```
You are designing a screen for the CMHO panel of AshaMitra — a Bengali-first
maternal-health system used by district health officers in West Bengal, India.
The user is a Chief Medical Officer of Health: she runs an entire district's
public health system and reads this standing up, between meetings. It is a
clinical command centre, not a business dashboard.

COLOUR SYSTEM — use these exact values:
- Page background: linear gradient #EDF3F5 → #E5EEF2 → #F5F9FB, top-left to
  bottom-right. A cool institutional mist, NOT warm.
- Cards: pure white #FFFFFF, radius 16-20, shadow rgba(20,37,43,0.04) blur 6 y+2.
- Brand: deep petrol teal #0E5A6B for buttons, active states, headers and key
  numbers. #08404E for emphasis. #14788C for charts. #E1EFF3 for icon chips and
  quiet fills. #CBDDE3 for borders and dividers.
- Text: #14252B primary, #5B6B72 secondary, #94A6AD light.
- CLINICAL COLOURS ARE RESERVED and never decorative:
    red #EF4444 = danger/missing/death, amber #FACC15 = warning,
    green #22C55E = safe, grey #CBD5DB = NO DATA RECEIVED.
- There is NO other accent colour. Do not add orange, pink or blue highlights —
  on a screen where red, amber and green each carry clinical meaning, a fourth
  decorative colour dilutes all of them.

TYPE: SolaimanLipi (a Bengali+Latin family). 24/700 h1, 20/600 h2, 17/600 h3,
15/400 body, 13/400 small, 13/600 label, 12/500 caption.
SPACING: 4/8/16/24/32. Page padding 16-24. Gaps between cards 10-16.

TONE: calm, authoritative, premium, uncluttered. Generous whitespace. Rounded and
human, but institutional — this is a government officer's instrument. NOT a
corporate SaaS console, NOT a fintech dashboard.

LANGUAGE: Bengali labels; keep these in Latin script because that is what health
staff actually say: ASHA, ANM, BMHO, CMHO, ANC, PNC, BP, HMIS, RED, YELLOW,
GREEN, Overdue, MgSO4, Oxytocin, FRU, ORS, IFA, NTEP, NCD, Nikshay, CRS, ILR, RRT.

HARD RULES:
- A metric with no data shows a grey em-dash "—", NEVER "0" or "0%".
- "No report received" is GREY, never green. Unknown must never look healthy.
- Percentages show their sample size ("50% (n=2)") or are greyed out.
- The most urgent, actionable thing is at the TOP. Totals and history go below.
- Every aggregate is tappable and drills down to named people with phone buttons.
- Bottom navigation: 5 icons, labels hidden, active one in a soft teal pill.
```

---

## 5. The eight screens

### Screen 1 — Dashboard (the one she opens)

```
Design the DASHBOARD (home) of a district health officer's panel. 720x1600 phone.

TOP: circular avatar left; "CMHO প্যানেল" 24px bold; beneath it "Dr. Sudipta Roy"
15px in secondary grey; a notification bell top-right with a small red badge.

THEN — the most important block on the screen — a section headed with a small red
lightning icon and "আজ যা করতে হবে (7)" in 13px semibold red. Below it, a vertical
stack of compact action cards. Each: white, radius 16, a 1px coloured border, a
small tinted icon chip on the left, a 13px bold title, a 12px grey sub-line, and a
chevron. Show these six, in this order:

  1. RED border, virus icon — "Ghosalpur — রোগ বাড়ছে" / "5 জন আক্রান্ত · Kolkata"
  2. RED, medicine-bottle icon — "Inj. MgSO4 নেই" / "3 জায়গায় — Kolkata, Kalyani"
  3. RED, female icon — "1 টি মাতৃমৃত্যু" / "ডেথ রিভিউ (MDSR) দরকার"
  4. RED, snowflake icon — "কোল্ড চেইনে সমস্যা (2)" / "টিকা নষ্ট হতে পারে"
  5. AMBER, truck icon — "2 টি রেফারেল আটকে আছে" / "৭ দিনের বেশি"
  6. TEAL-GREY, person-off icon — "2 জন ASHA ৩০ দিন নিষ্ক্রিয়" / "Puja, affan das"
Below the stack, a small grey line: "+ আরও 3 টি বিষয়".

THEN a row of THREE equal quick-link tiles — white, radius 16, a tinted icon chip
on top and a two-line 12px bold Bengali label centred beneath:
  [pill bottle, red chip]   "ওষুধ ও\nপ্রস্তুতি"
  [shield-health, teal chip] "স্বাস্থ্য\nকর্মসূচি"
  [building, teal chip]      "জেলা\nপরিচালনা"

THEN a 2x2 grid of stat tiles (white, radius 16, tinted icon chip top-left, a
large 28px number in teal #0E5A6B, a 12px grey Bengali caption, and a faint
sparkline across the bottom of the tile):
  "4 মোট ASHA" · "8 মোট রোগী" · "36 মোট রিপোর্ট" · "25 জরুরি (RED)" (number in red)

THEN a white card "ঝুঁকির ভাগ" containing a donut chart — RED 25 / YELLOW 7 /
GREEN 0 — with a legend listing each band, its colour dot and its count.

FINALLY "সাম্প্রতিক রিপোর্ট" — a list of report cards, each with a coloured left
stripe (red/amber/green), the case title in 13px bold, the patient name in grey,
and a right-aligned timestamp like "11 Jun, 07:45".

Bottom nav: 5 icons (grid, chart-line, people, bar-chart, gear), labels hidden,
the active one sitting in a soft teal #E1EFF3 pill, a red count badge on the
chart-line icon.
```

### Screen 2 — District Analytics

```
Design the DISTRICT ANALYTICS screen of a CMHO panel. 720x1600 phone.

HEADER: "জেলা বিশ্লেষণ" 24px bold; grey sub-line "CMHO · গত 12 মাস". On the right
a circular PDF-export button and a segmented pill "3 মাস | 12 মাস" with the active
segment filled deep teal #0E5A6B and white text.

SECTION "HMIS মূল সূচক" with grey subtitle "সরকারি HMIS ফর্মুলা অনুযায়ী".
A 2-column grid of white metric tiles (radius 16): a tinted icon chip top-left, a
28px value, a 12px Bengali caption, and a small top-right delta arrow coloured by
MEANING — green when the change is good, red when bad:
  "2 · প্রসূতি নথিভুক্ত" (↑2.0 green)      "100.0% · ১ম ত্রৈমাসিকে ANC"
  "50.0% (n=2) · 8+ ANC ভিজিট"            "1 · উচ্চ ঝুঁকি প্রসূতি" (↑1 red)
  "— · প্রাতিষ্ঠানিক প্রসব"                 "— · সিজার"
  "— · কম ওজনের শিশু (<২.৫ কেজি)"          "11.1% · টিকা কভারেজ"
  "13 · টিকা বাকি (Overdue)" with a small red "এখন ›" chip meaning it is tappable
  "100.0% · রেফারেল সম্পন্ন"
CRITICAL: the "—" tiles are a designed state meaning "no data yet". They must look
calm and deliberate in grey — never broken, never zero.

THEN a white card "মাসে মাসে কাজ" / "কোন মাসে কী হয়েছে — নিচে নামছে কি না".
Inside: a legend row with two small squares — pale teal "মোট" and red "RED" — then
a MONTHLY BAR CHART. One bar group per month across 13 months, each month drawn as
a pale teal bar with a solid red bar overlaid in front of it. Three faint
horizontal gridlines. Below the bars, only three month labels: leftmost, middle
and rightmost ("জুলা", "জানু", "জুলা"). Beneath the chart a red warning line with a
downward-trend icon: "এই মাসে এখনও কোনও রিপোর্ট আসেনি — কর্মীদের সঙ্গে কথা বলুন".
Then two more smaller bar charts in the same card, labelled "টিকা দেওয়া হয়েছে"
and "নতুন প্রসূতি নথিভুক্ত".

THEN a white card "লক্ষ্যের তুলনায়" / "সবচেয়ে বেশি পিছিয়ে যেটা — সেটা আগে".
Inside, a list of BENCHMARK BARS, biggest shortfall first. Each row: the indicator
name on the left in 13px semibold; on the right the current value then the target
in light grey ("11.1%   লক্ষ্য 90%"); beneath, a full-width 10px track in very pale
grey, filled proportionally in RED when the target is missed and GREEN when met,
with a small dark vertical tick marking the target position on the track.
  "টিকা কভারেজ  11.1%  লক্ষ্য 90%"   (red fill, tick far right)
  "8+ ANC ভিজিট  50%  লক্ষ্য 70%"    (red)
  "১ম ত্রৈমাসিকে ANC  100%  লক্ষ্য 90%" (green)
  "প্রাতিষ্ঠানিক প্রসব  —  লক্ষ্য 95%"  (empty grey track, grey dash)

THEN two entry cards, full width, white, radius 20, 1px coloured border, tinted
icon chip, title, sub-line, count badge and chevron:
  [shield-health] "স্বাস্থ্য কর্মসূচি" / "12 জনের জন্য এখনই ব্যবস্থা দরকার"  badge 12
  [building]      "জেলা পরিচালনা"     / "2 টি গ্রামে রোগ বাড়ছে — এখনই দেখুন"  badge 9

FINALLY two ranked cards, "ব্লক অনুযায়ী পারফরম্যান্স" and "BMHO অনুযায়ী পারফরম্যান্স",
each with grey subtitle "কে পিছিয়ে আছে — সেটাই এখানে দেখা যায়". Rows worst-first:
name in 15px semibold, a thin horizontal bar, then small grey stat chips with tiny
icons — "3 ASHA · 0 জন্ম · 11% টিকা · 36 রিপোর্ট". A small red dot on any block
with a maternal death.
```

### Screen 3 — Health Programmes

```
Design a "National Health Programmes" screen for a CMHO. 720x1600 phone.

HEADER: back arrow, "স্বাস্থ্য কর্মসূচি" 24px bold, grey sub-line
"CMHO · জেলা · জাতীয় কর্মসূচির অবস্থা", refresh icon right. Beneath, right-aligned,
a segmented pill "3 মাস | 12 মাস" (active filled #0E5A6B, white text).

A vertical stack of five COLLAPSIBLE PROGRAMME CARDS, white, radius 20. A card
with urgent work carries a thin red border and a red count badge.

Collapsed layout: tinted icon chip left, programme name 17px semibold, red badge
if urgent, chevron; then BELOW, a row of 3-4 headline stats — a 20px number above
a 12px grey Bengali label. Alarming numbers in red; no-data as a grey "—".

  CARD 1 "যক্ষ্মা (NTEP)" — RED BORDER, badge "5", virus icon, EXPANDED:
    stats: "12 চিকিৎসাধীন" | "3 সন্দেহভাজন" | "4 ডোজ বাদ পড়েছে" (red) |
           "1 Nikshay-এ নেই" (red)
    Two action groups. Each: a 3px red vertical bar, a bold red title, a count on
    the right, then named people — name in 13px semibold, a 12px grey detail line,
    and a small round phone button on the right:
      ▌ডোজ বাদ পড়েছে — চিকিৎসা ভেঙে যাচ্ছে              4
          Rahim Sheikh · 4 ডোজ বাদ · Ghosalpur · Kolkata      [phone]
          Anima Das · 2 ডোজ বাদ · Baruipara · Kalyani         [phone]
      ▌Nikshay ID নেই — রাজ্যের হিসাবে নেই                 1
          Sabina Bibi · Pulmonary TB · Newtown                [phone]
    Then a small "ব্লক অনুযায়ী" list: "Kolkata 3/7", "Kalyani 1/4" in red.

  CARD 2 "NCD স্ক্রিনিং" (heart-monitor icon), collapsed:
    "148 স্ক্রিন করা হয়েছে" | "22 উচ্চ ঝুঁকি (CBAC ≥ 4)" (red) |
    "9 জানা ডায়াবেটিস" | "14 জানা উচ্চ রক্তচাপ"
  CARD 3 "পরিবার পরিকল্পনা" (family icon), collapsed:
    "64 যোগ্য দম্পতি" | "41 পদ্ধতি নিয়েছেন" | "23 পদ্ধতি নেননি" (red) | "64.1% কভারেজ"
  CARD 4 "জন্ম-মৃত্যু নিবন্ধন (CRS)" (verified-person icon), collapsed:
    "18 জন্ম" | "3 মৃত্যু" | "5 নিবন্ধন বাকি" (red) | "76.2% নিবন্ধিত"
  CARD 5 "ওষুধ ও সরবরাহ" (pill icon), collapsed and calm:
    "0 কম স্টক লাইন"; expanded shows a green check row "এই মুহূর্তে কিছু করার নেই"

AT THE BOTTOM, a quiet grey rounded box (no shadow, not a white card) with a small
info icon and 12px grey text: "এখানে শুধু সেই কর্মসূচি দেখানো হয় যেগুলোর তথ্য ASHA
কর্মীরা এই অ্যাপে তোলেন। ম্যালেরিয়া/ডেঙ্গু সার্ভেইল্যান্স, কুষ্ঠ, অন্ধত্ব — এগুলোর
তথ্য এখনও সংগ্রহ করা হয় না, তাই দেখানো হয়নি।"
This note is deliberate — it stops a missing programme from looking like a healthy
one. Do not remove it.
```

### Screen 4 — District Operations

```
Design a "District Operations" screen for a CMHO. 720x1600 phone. This is the
administrative half of her job.

HEADER: back arrow, "জেলা পরিচালনা" 24px bold, grey sub-line
"CMHO · রোগ নজরদারি · কেন্দ্র · কোল্ড চেইন · কর্মী", refresh icon right.

NINE collapsible cards, same pattern as the programmes screen (white, radius 20,
tinted icon chip, title + grey sub-line, red badge when urgent, a row of headline
stats, chevron). Order matters — it is ranked by how fast the thing harms someone:

  1 "রোগ নজরদারি" (virus) — RED BORDER, badge 2, EXPANDED.
    stats: "23 ৭ দিনে কেস" | "2 ক্লাস্টার" (red) | "3 ম্যালেরিয়া +" | "1 ডেঙ্গু সন্দেহ"
    Expanded: two red-tinted cluster panels (radius 16, pale red fill, red border):
      "জ্বর — Ghosalpur"                                    "5 কেস"
      12px grey: "স্বাভাবিক 1.3 → এখন 5 (3.8× বেশি) · Kolkata"
      then named people rows with a small red warning triangle where there are
      danger signs, and a phone button.
      "ডায়রিয়া — Baruipara"                                 "4 কেস"
      12px grey: "আগে এই রোগ ছিল না — হঠাৎ 4 জন · Kalyani"
  2 "প্রাদুর্ভাব ও জরুরি অবস্থা" (siren) — sub-line "যা এখনও করা হয়নি — সেটাই দেখানো হয়"
    stats: "1 চলমান" | "3 বন্ধ হয়েছে". Expanded shows the outbreak title and, as a
    wrap of small RED pills, the responses NOT yet arranged: "জল পরীক্ষা",
    "ক্লোরিনেশন", "ORS ক্যাম্প".
  3 "কোল্ড চেইন" (snowflake) — RED BORDER, sub-line
    "ILR ২–৮°C-এর বাইরে গেলে পুরো ব্লকের টিকা নষ্ট হয়"
    stats: "12 পয়েন্ট" | "9 ৭ দিনে খবর" | "2 সমস্যা" (red) | "3 খবর নেই" (amber)
  4 "স্বাস্থ্য কেন্দ্র" (hospital) — "48 মোট কেন্দ্র" | "6 রাতে প্রসব হয় না" (red)
    Expanded: a wrap of teal pills "PHC 22", "HWC 14", "SC 8", "BPHC 4".
  5 "কর্মী ও শূন্যপদ" (badge) — "310 অনুমোদিত" | "268 কর্মরত" | "42 শূন্য" (red) |
    "86.5% পূরণ". Expanded: rows "ANM · Kalyani BPHC   3/5   [2 শূন্য]".
  6 "পরিদর্শন ও মান" (clipboard-check) — "18 পরিদর্শন" | "74% গড় স্কোর" | "6 কখনও হয়নি"
  7 "প্রশিক্ষণ" (graduation cap) — "9 সেশন" | "212 প্রশিক্ষিত" | "260 ডাকা হয়েছিল"
  8 "সভা ও সিদ্ধান্ত" (people-group) — "6 সভা" | "11 বাকি কাজ" | "4 সময় পেরিয়েছে" (red)
  9 "বাজেট ব্যবহার" (wallet) — "সবচেয়ে নিচে" — "48.2% ব্যবহার"; expanded ends with a
    small light-grey note: "এটি শুধু নজরদারির জন্য — কোনও অনুমোদন, অডিট বা পেমেন্ট
    এখানে হয় না।"

Cards with nothing wrong show a green check row "সব ঠিক আছে". Cards with NO DATA
show a grey info row "তথ্য যোগ করা হয়নি" — these two states must look clearly
different from each other.
```

### Screen 5 — Supply & Readiness (the heatmap)

```
Design a medical-supply readiness screen for a CMHO. 720x1600 phone.

HEADER: back arrow, "ওষুধ ও প্রস্তুতি" 24px bold, grey sub-line
"CMHO · জেলা → ব্লক → উপকেন্দ্র", refresh icon right.

CARD 1 — coverage. Left: a donut with THREE segments — green "খবর দিয়েছে", amber
"পুরোনো খবর", grey "কখনও খবর দেয়নি" — with "9/14" and the caption "খবর দিয়েছে" in
its centre. Right: two stacked stats, "2 জরুরি ঘাটতি" in red and "5 খবর নেই" in amber.

CARD 2 — a red-tinted panel "প্রাণরক্ষাকারী জিনিস নেই" with the grey subtitle
"একদিনে ঠিক করা যায় — এবং করলে জীবন বাঁচে". Rows like:
  [red count pill "3"]  Inj. MgSO4 (খিঁচুনি/এক্লাম্পসিয়া)
      Arpita Das · Kolkata
      Sayantani Das · Kolkata
Names and places must be legible — not fine print. They are the point.

CARD 3 — THE HEATMAP, "ব্লক × ওষুধ/যন্ত্র", subtitle "লাল = নেই · ধূসর = খবরই আসেনি".
A grid: the LEFT column is a fixed list of supply names in 12px Bengali; the grid
to its right scrolls horizontally, one column per block (Kolkata, Kalyani,
Newtown, HQ) with the block name above each column. Every cell is a 44x30 rounded
square:
    red #EF4444   নেই  (with a small white count if >1)
    amber #FACC15 কম
    green #22C55E আছে
    grey  #CBD5DB খবর নেই      ← MUST be grey. Never green.
Critical supplies come FIRST and carry a thin red vertical bar beside their label:
BP মেশিন · অ্যাম্বুলেন্স (102/108) · Inj. MgSO4 · Inj. Oxytocin · FRU-তে রক্ত.
Beneath the grid, a legend of four small colour swatches: নেই / কম / আছে / খবর নেই.

CARD 4 — "ব্লক অনুযায়ী অবস্থা", worst first. Per block: name, then a thin 8px
horizontal stacked bar segmented red/amber/green/grey by proportion, with a small
red "2 নেই" label right-aligned.

FINALLY expandable block rows: "Kalyani" with a red pill "1 জরুরি ঘাটতি"; tapping
reveals the people inside — a coloured status dot, "name · sub-centre", and a
status line like "কখনও খবর দেয়নি" or "3 দিন আগের খবর".

The heatmap is the hero. Give it room to breathe.
```

### Screen 6 — Workers

```
Design the WORKERS screen of a CMHO panel. 720x1600 phone.

HEADER: "কর্মী" 24px bold, grey sub-line "CMHO · 4 BMHO · 12 ANM · 96 ASHA", a
search icon and a filter icon on the right.

A horizontal row of filter chips beneath: "সবাই" (active — filled teal #0E5A6B,
white text), "BMHO", "ANM", "ASHA", "নিষ্ক্রিয়" — the inactive chips white with a
#CBDDE3 border.

Then a list of worker cards: white, radius 16. Each has a circular avatar (photo
or initial on a pale teal #E1EFF3 circle), the name in 15px semibold, a small role
chip beside it ("BMHO" in teal, "ASHA" in grey), then a 12px grey line with block
and sub-centre. On the right, a small round teal phone button.
Beneath, a row of small stat chips with tiny icons:
  "4 ASHA · 36 রিপোর্ট · 25 RED"  — the RED number in red when above zero.
A worker inactive for 30+ days shows a small amber pill "৩০ দিন নিষ্ক্রিয়".

Include one card in each state: a healthy BMHO, an ANM, an ASHA with 25 RED, and
an inactive ASHA with the amber pill.
```

### Screen 7 — Reports

```
Design the REPORTS screen of a CMHO panel. 720x1600 phone.

HEADER: "রিপোর্ট" 24px bold, grey sub-line "গত 12 মাস · 36 টি", with a search icon
and a download/PDF icon on the right.

A row of filter chips: "সব" (active, filled teal), "RED", "YELLOW", "GREEN",
"আজ", "এই সপ্তাহ".

Then a small summary strip — three side-by-side mini counts separated by thin
vertical rules: "25 RED" in red, "7 YELLOW" in amber, "0 GREEN" in green.

Then the report list. Each card: white, radius 16, with a 4px full-height coloured
stripe down its left edge (red/amber/green by band). Inside: the case type in 15px
semibold ("জরুরি অবস্থা", "শিশু স্বাস্থ্য", "টিকাকরণ"), the patient name in 13px
grey beneath, then a wrap of small pale chips for danger signs ("তীব্র জ্বর",
"খিঁচুনি"), and a right-aligned 12px timestamp "11 Jun, 07:45". Beneath that, a
12px grey line "Affan · Kolkata" naming the reporting ASHA.

Show 4 cards: two RED, one YELLOW, one GREEN.
```

### Screen 8 — Profile & Settings

```
Design the PROFILE / SETTINGS screen of a CMHO panel. 720x1600 phone.

HEADER: "প্রোফাইল" 24px bold.

CARD 1 — identity. A large circular avatar with a small camera badge, the name
"Dr. Sudipta Roy" in 20px semibold, the phone number "9000000001" in 15px grey,
and a small teal pill reading "CMHO" (the RANK, not a generic "admin" label).

CARD 2 — "প্রোফাইল সম্পাদনা": three outlined input fields with leading icons —
"পুরো নাম", "ব্লক", "জেলা" — and a full-width deep-teal "সেভ করুন" button.

CARD 3 — language: a single row, globe icon in a pale teal chip, "ভাষা পরিবর্তন
করুন", with "বাংলা (Bengali)" right-aligned in grey and a chevron.

CARD 4 — "জরুরি অ্যালার্ট". A red-tinted bell icon chip, the title, then 13px grey
body text: "আপনার টিমের কোনও বিপদচিহ্ন (RED) ধরা পড়লে সঙ্গে সঙ্গে এই ফোনে
নোটিফিকেশন আসবে — অ্যাপ বন্ধ থাকলেও।" Below it a full-width outlined teal button
with a send icon: "নোটিফিকেশন পরীক্ষা করুন".

CARD 5 — a red outlined full-width "লগআউট" button with a logout icon.

Calm, spacious, institutional. Cool teal on mist, not warm purple.
```

---

## 6. What Stitch will get wrong — reject these

| It will produce | Why it is wrong here |
|---|---|
| A choropleth map of India / West Bengal | You have block **names** only. No coordinates, no boundaries. Nothing to draw. |
| A smooth line chart of the monthly series | These are monthly **counts**. A curve between two months implies values nobody measured. Use bars. |
| "0%" tiles | The API returns `null`. Rendering `0%` invents a catastrophe out of an absence of births. |
| Green "all systems normal" banners | Silence is not health. Grey means unknown. |
| An orange or blue accent | The palette is teal + three clinical colours + grey. A fourth colour dilutes the three that carry meaning. |
| Revenue / KPI / growth language | This is a maternal-death system. There is no growth to celebrate. |
| Purple anywhere | That is the ASHA worker app. The CMHO panel is teal. |
| Dense 12-column tables | 720×1600 phone, held one-handed, often outdoors. |
