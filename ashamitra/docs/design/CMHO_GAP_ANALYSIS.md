# CMHO Panel — What's Built, What's Pending

Measured against the official CMHO role definition (14 responsibility areas).
Verified against the codebase, not from memory. Last checked: 2026-07-22.

**Legend:** ✅ built · 🟡 partial · ❌ pending

---

## Scorecard — updated 2026-07-22 after the district-operations build

| # | Responsibility area | Status | Where it stands |
|---|---|---|---|
| 1 | Administrative (facilities) | ✅ | `Facility` model — type, services, staffing, incharge |
| 2 | Human Resource Management | 🟡 | Roster, performance, **sanctioned vs in-post gap**. No leave/salary — deliberate |
| 3 | Drug & Logistics | ✅ | Readiness pulse + monthly ledger + facility services |
| 4 | Immunization Programme | ✅ | Coverage, defaulters by name, **cold chain (ILR temp, power cuts)** |
| 5 | National Health Programmes | 🟡 | **7 of 8** — leprosy and blindness still absent |
| 6 | Disease Surveillance | ✅ | `Surveillance` + village-level cluster detection |
| 7 | Outbreak Investigation | ✅ | `Outbreak` + RRT response checklist |
| 8 | Budget & Financial | 🟡 | Visibility only — allocation vs spend. **No approval/audit/payment, by design** |
| 9 | Monitoring & Evaluation | ✅ | Indicators, monthly trends, benchmark gaps, ranking, PDF |
| 10 | Health Data Management | 🟡 | **Stillbirths now countable**; state export format still missing |
| 11 | Training & Capacity Building | ✅ | `Training` — sessions, attendance vs invited |
| 12 | Disaster & Emergency | ✅ | `Outbreak` covers flood/cyclone/epidemic with the same checklist |
| 13 | Hospital Inspection & QA | ✅ | `Inspection` — checklist, score, never-inspected list |
| 14 | Meetings & Coordination | ✅ | `Meeting` + open action items with owner and due date |

**10 of 14 fully served, 4 partial.** Was 3 of 14.

### What is deliberately still open

- **5 — leprosy and blindness.** No collection. Both are screening-and-referral
  programmes that would fit the existing module pattern, but neither has been
  asked for and inventing the fields would be guessing.
- **2 — leave, postings, salary, promotions.** Still argued against. These belong
  in a government HR system with legal records; a parallel copy creates disputes
  about which is authoritative.
- **8 — budget beyond visibility.** Approval workflow and treasury integration
  need audit trails this app cannot provide.
- **10 — state export.** The data is all there; what is missing is the specific
  HMIS/state upload format, which has to be taken from the actual state template
  rather than assumed.

---

## Area 5 in detail — National Health Programmes

| Programme | Status | Source |
|---|---|---|
| A. NTEP (TB) | ✅ | `TbCase` — registration, DOTS adherence, Nikshay, sputum |
| B. Vector-borne (malaria, dengue) | ❌ | **no data collected** |
| C. Leprosy | ❌ | no data collected |
| D. Blindness | ❌ | no data collected |
| E. Family Planning | ✅ | `EligibleCouple` — methods, unmet need |
| F. Maternal Health | ✅ | full ANC/PNC/high-risk/MDSR |
| G. Child Health | 🟡 | immunization ✅, **growth monitoring / nutrition ❌** |
| H. NCD | ✅ | `NcdCbac` — CBAC, diabetes, hypertension |

---

## What is genuinely worth building next

Ranked by **lives affected per unit of work**, not by how impressive the screen looks.

### 1. Fever & diarrhoea surveillance ⭐ highest value
**Unlocks areas 6 and 7, plus malaria and dengue in area 5 — four gaps from one change.**

The triage engine has exactly seven case types, all RCH (`newborn, child, infant,
pregnancy, postpartum, immunization, emergency`). There is no fever pathway, so
the app is blind to the most common reason a villager seeks care.

Add a `fever` case type collecting: onset date, duration, danger signs, village.
Then a **village-level cluster alert** — "5 fever cases in Ghosalpur this week,
baseline 1" — pushed to the CMHO. That is the RRT trigger the role definition
describes, and it is the single highest-value addition available.

*Effort: moderate (one triage case type + a clustering rule).*

### 2. Cold chain monitoring ⭐ high value, low effort
Area 4's biggest hole. A failed ILR silently destroys an entire block's vaccine
stock, and nothing in the system would say so. The readiness pulse already exists
and already has ANMs answering a 3-tap form — **add ILR/deep-freezer temperature
and power-cut hours to that same form.** Reuses the whole escalation chain.

*Effort: small. This is mostly a data addition to a screen that already works.*

### 3. Stillbirths
`VitalEvent.eventType` accepts only `birth` and `death`. Stillbirth is explicitly
named in area 10 and is a core maternal-health indicator (SBR). Currently
uncountable.

*Effort: tiny — one enum value plus a field, and the CRS card already exists.*

### 4. TB treatment success rate
`TbCase.outcome` is already collected (cured/completed/died/lost) but never
computed into an indicator. Area 9 names it explicitly.

*Effort: tiny — one aggregation in the programmes endpoint.*

### 5. Broadcast / message channel
You asked for this earlier and it is still pending. CMHO → block, BMHO → ANMs,
with read receipts. Push already works, so this is mostly a model plus a screen.
**Must be targeted, never broadcast-to-all** — a megaphone gets muted, and a muted
app stops delivering the RED alerts too.

*Effort: moderate.*

### 6. Growth monitoring / nutrition
Area 5G. Weight-for-age, MUAC, SAM/MAM flagging, NRC referral. This is real
child-mortality work and genuinely missing.

*Effort: moderate — a new module.*

---

## What should probably NOT be built here

Not because they don't matter, but because a phone app used by ASHA workers is
the wrong instrument, and a half-built version is worse than none.

| Area | Why not |
|---|---|
| 2 — leave, postings, salary, promotions | These belong in a government HR system with legal records. A parallel copy creates disputes about which one is authoritative. |
| 8 — budget & expenditure | Financial systems need audit trails and treasury integration. |
| 11 — training records | Better as a simple register; only worth it if attendance is captured at the event. |
| 13 — hospital inspection / OT / BMW | Needs area 1 (facility model) first, and the inspector is not an ASHA. |
| 14 — meeting minutes | A document workflow, not a field-data workflow. |

**Area 1 (facility model) is the real fork in the road.** Areas 1, 13 and much of
3 all depend on it. Adding `Facility` (type, name, block, staff sanctioned vs in
post, services available) would turn this from a *worker* app into a *district
health system*. That is a significant scope decision, not a feature — worth
making deliberately rather than drifting into.

---

## Already solid — do not rebuild

- **Area 9 (M&E)** — HMIS indicators, real monthly trends, benchmark gaps, block
  and team ranking, PDF export. This is the strongest part of the panel.
- **Area 3 at sub-centre level** — the readiness pulse (MgSO4, oxytocin, BP
  machine, ambulance, FRU blood) with instant escalation up the chain.
- **Areas 5A/5E/5F/5H** — NTEP, family planning, maternal health, NCD.
- **Escalation** — RED alerts reach the supervisor's phone by push, verified
  end-to-end on a real handset.
