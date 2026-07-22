# AshaMitra — Supervisor Panel Design System

The single source of truth for redesigning the **CMHO**, **BMHO** and **ANM** panels so they
feel like one product with the ASHA app — not three dashboards that happen to share a login.

Every value here is lifted from the live code (`lib/core/theme/*`). If a token is not in this
file, it does not exist in the app, and a design that uses it cannot be built.

---

## 1. Colour

The ASHA app is **deep purple on soft sage-green**. That is the identity. Supervisor panels use
the *same* palette — they are not a separate brand, and they must not drift to the corporate
blue-grey that every admin dashboard defaults to.

### Brand
| Token | Hex | Use |
|---|---|---|
| `primary` | `#791C87` | Buttons, links, active nav, key numbers |
| `primaryDeep` | `#5B0F69` | Emphasis on dark surfaces |
| `primarySoft` | `#F6E9F9` | Quiet fills, focus halos, icon chips |
| `accent` | `#FC8155` | Warm highlights, callouts |
| `accentDeep` | `#C2410C` | Accent emphasis |
| `accentSoft` | `#FFE8DC` | Soft accent fills |
| `purple` (magenta) | `#BD3773` | Decorative gradient partner |
| `sky` (teal) | `#0EA5B5` | Variety in tiles — use sparingly |

### Clinical bands — these three colours are **reserved**
Never use them decoratively. On this app, red means *a person is in danger*.

| Token | Hex | Meaning |
|---|---|---|
| `emergencyRed` | `#EF4444` | RED band, missing life-saving supply, maternal/infant death |
| `warningYellow` | `#FACC15` | YELLOW band, low stock, stale report |
| `safeGreen` | `#22C55E` | GREEN band, available, all-clear |

### Surfaces
| Token | Hex |
|---|---|
| `background` | `#EAF3EC` (soft sage-green) |
| `surface` | `#FFFFFF` |
| `surfaceMuted` | `#F3F6F3` |
| `onBackground` (text) | `#241726` (deep purple-near-black) |
| `textSecondary` | `#6B7280` |
| `textLight` | `#9CA3AF` |
| `cardBorder` | `#E3DCE8` |

### Gradients
```
background       #EAF3EC → #E3F0E8 → #F1F8F3   (topLeft → bottomRight)  ← every page
primary          #791C87 → #BD3773             (topLeft → bottomRight)
primaryVertical  #791C87 → #A8277E → #BD3773   (top → bottom)
emergency        #EF4444 → #DC2626             (topLeft → bottomRight)
```

**Every screen sits on the `background` gradient. Cards are pure white on top of it.** That is
what makes the app feel calm rather than clinical.

---

## 2. Type

**Font: `SolaimanLipi`** (bundled). One family for Bengali and Latin — do not introduce a second.

| Style | Size | Weight | Line-height |
|---|---|---|---|
| `display` | 32 | 700 | 1.20 |
| `h1` | 24 | 700 | 1.25 |
| `h2` | 20 | 600 | 1.30 |
| `h3` | 17 | 600 | 1.35 |
| `bodyLg` | 16 | 400 | 1.50 |
| `body` | 15 | 400 | 1.45 |
| `bodySm` | 13 | 400 | 1.40 (secondary colour) |
| `labelLg` | 15 | 600 | 1.30 |
| `label` | 13 | 600 | 1.30 |
| `caption` | 12 | 500 | 1.30 (secondary colour) |
| `overline` | 11 | 600 | 1.20, +0.6 letter-spacing |

### Language
**Bengali first, with the English terms workers actually use.** This is a deliberate, tested
choice — not laziness. Keep these in Latin script:

> ASHA · ANM · BMHO · CMHO · ANC · PNC · BP · HMIS · MCP · RED · YELLOW · GREEN ·
> Overdue · Upcoming · ORS · IFA · MgSO4 · Oxytocin · FRU · DDK · zero-reporting

Say **ভিজিট** not পরিদর্শন, **সেভ** not সংরক্ষণ, **Overdue** not বকেয়া, **ব্লাড সুগার** not রক্তে শর্করা.

---

## 3. Shape, depth, rhythm

**Radius:** `sm 8` (chips) · `md 12` (inputs) · `lg 16` (standard cards) · `xl 20` (hero cards) ·
`xxl 28` (sheets) · `pill 999`

**Shadow — three tiers only, never ad-hoc:**
```
low   rgba(36,23,38,0.04)  blur 6   y+2    ← standard cards
mid   rgba(36,23,38,0.06)  blur 12  y+4    ← raised / interactive
high  rgba(36,23,38,0.10)  blur 20  y+8    ← modals, sheets
```

**Spacing scale:** `4 · 8 · 16 · 24 · 32 · 48`. Page padding `16–24`. Card padding `14–20`.
Gap between cards `10–16`.

---

## 4. The seven rules that are not negotiable

A supervisor panel is a clinical instrument. These rules exist because breaking them produces a
screen that is *confidently wrong*, which is worse than a screen that says nothing.

**1. `—` is not `0`.**
The API returns `null` for a percentage whose denominator is zero. Render it as **`—`**, never as
`0%`. "0% institutional delivery" reads as a catastrophe; the truth is "no births recorded yet".
The design must have a first-class *no-data* state for every metric tile.

**2. Grey is not green.**
"Nobody reported" must never look like "everything is fine". A supply grid where an unreported
cell is green will tell a CMHO her district is stocked when she has simply heard nothing. Unknown
is **grey**, and it is *counted out loud* next to the failures.

**3. Show the denominator, or suppress the number.**
`50.0%` from n=2 is one woman. A decimal point is a claim of precision the data cannot support.
Any percentage must carry its `n`, or be greyed below a minimum sample.

**4. Escalations lead. Vanity totals do not.**
The top of every panel answers *"what must I do before tonight?"* — not *"how many reports have
we ever collected?"* Missing MgSO4, maternal death, stranded referral, silent ASHA. Totals go
below the fold.

**5. Names, not rates.**
A supervisor cannot act on "13 overdue". She acts on *"Puja · Kolkata · 12 days · tap to call"*.
Every aggregate must drill down to people, with a phone number at the end of it.

**6. Trend arrows are coloured by meaning, not direction.**
↑ institutional delivery = **green**. ↑ maternal deaths = **red**. ↑ C-section = *neither* —
it is context-dependent, so show the delta without a verdict.

**7. Live, not stale.**
Pull-to-refresh on every screen. Any figure older than its window says so. RED alerts arrive by
push (FCM, channel `ashamitra_alerts`, importance HIGH) — the panel is not the only way she finds out.

---

## 5. Shell — identical across all three panels

Bottom navigation, 5 destinations, labels hidden, badge on District:

| # | Tab | Purpose |
|---|---|---|
| 1 | Overview | Today, at a glance |
| 2 | District / Block / Area | The analytics + the drill-down |
| 3 | Workers | The team below me |
| 4 | Reports | Every triage report, filterable |
| 5 | Settings | Profile, language, alerts, logout |

The **panel name is dynamic**: `CMHO প্যানেল` / `BMHO প্যানেল` / `ANM প্যানেল`, with the officer's
name beneath. The geography line follows the role:

- **CMHO** — `জেলা → ব্লক → উপকেন্দ্র`
- **BMHO** — `ব্লক → উপকেন্দ্র → ANM/ASHA`
- **ANM** — `উপকেন্দ্র → ASHA`

---

## 6. Stitch AI — preamble to paste before every screen prompt

```
You are designing a screen for AshaMitra, a Bengali-first maternal-health app used by
government health officers in West Bengal, India. It is a clinical instrument, not a
business dashboard.

DESIGN SYSTEM (use these exact values):
- Page background: linear gradient #EAF3EC → #E3F0E8 → #F1F8F3, top-left to bottom-right.
- Cards: pure white #FFFFFF, radius 16-20px, shadow rgba(36,23,38,0.04) blur 6px y+2.
- Brand purple #791C87 for buttons, active states and key numbers.
- Soft purple #F6E9F9 for icon chips and quiet fills.
- Accent orange #FC8155 used sparingly.
- Clinical colours are RESERVED and never decorative:
    red #EF4444 = danger, amber #FACC15 = warning, green #22C55E = safe.
- Text: #241726 primary, #6B7280 secondary. Font: SolaimanLipi (a Bengali+Latin family).
- Type scale: 24/700 h1, 20/600 h2, 17/600 h3, 15/400 body, 13/600 label, 12/500 caption.
- Spacing 4/8/16/24/32. Page padding 16-24. Gaps between cards 10-16.

TONE: calm, warm, premium, uncluttered. Generous whitespace. Rounded, soft, human —
NOT a corporate blue-grey admin console. This must feel like the same product as the
worker's app, which is purple-on-sage-green.

LANGUAGE: Bengali labels, but keep these terms in Latin script because that is what the
workers actually say: ASHA, ANM, BMHO, CMHO, ANC, PNC, BP, HMIS, RED, YELLOW, GREEN,
Overdue, MgSO4, Oxytocin, FRU, ORS, IFA.

HARD RULES:
- A metric with no data shows an em-dash "—", NEVER "0" or "0%".
- "No report received" is GREY, never green. Unknown must never look like healthy.
- Percentages show their sample size (e.g. "50% (n=2)") or are greyed out.
- The most urgent, actionable thing is at the TOP. Totals and history go below.
- Every aggregate is tappable and drills down to named people with phone numbers.
```

Then paste the screen-specific prompt from `PANEL_CMHO.md`, `PANEL_BMHO.md` or `PANEL_ANM.md`.

---

## 7. What Stitch will get wrong unless you stop it

Left alone, an AI UI generator will produce a beautiful screen that **cannot be built** and
**lies to a health officer**. Watch for these and reject them:

| It will do this | Why it's wrong |
|---|---|
| A world map / choropleth of India | You have block *names* (`Kolkata`, `Newtown`). No coordinates, no boundaries. There is nothing to draw. |
| "0%" tiles everywhere | Your API returns `null`, not `0`. Rendering `0%` invents a catastrophe. |
| Green "all systems normal" banners | Silence is not health. See rule 2. |
| Revenue / KPI / growth-chart language | This is a maternal-death system. There is no growth to celebrate. |
| Blue-grey SaaS admin theme | Wrong brand. Purple on sage-green, or it isn't AshaMitra. |
| Sparkline on every tile | You only have `current` vs `prev` — two points. A two-point sparkline is decoration pretending to be data. |
| Dense 12-column data tables | These are 720×1600 phones held one-handed in a village. |
