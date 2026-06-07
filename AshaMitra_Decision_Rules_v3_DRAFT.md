# AshaMitra — Clinical Decision Rules **v3.0 (DRAFT for clinical sign-off)**

**Status:** Proposed upgrade to engine `asha_cdss_engine v1.0.0` / cases `v2.0.0`.
**Author of this draft:** Tooling/design proposal — **NOT a clinical authority.**
**Nothing in this document is validated.** Every new or changed clinical threshold below is tagged
`[DRAFT — SIGN-OFF]` and must be reviewed and approved by **AIIH&PH / WB Health Secretariat clinical
committee** before it touches `clinical_decision_engine.json` or `triage_cases.json`.

> **Design intent.** This upgrade does **not** try to make the app "diagnose like a doctor." The ASHA's
> role is *recognise danger signs → refer correctly*. The clinical expertise lives in the **rules**
> (committee-validated); the engine stays deterministic, offline, no-LLM, and biased toward over-referral.
> The goal of v3.0 is **completeness, correct thresholds, and safe handling of uncertainty** — so the tool
> remains defensible under review.

Protocol basis (unchanged): HBNC, IMNCI (incl. Young Infant 0–2 m), HBYC, MCP, PMSMA, SBA, PPH, PNC, UIP.

---

## PART A — Design-layer upgrades (apply across all modules)

These are higher-impact than any single rule, because they fix gaps that affect *every* case.

### A1. Universal danger-sign pre-sweep `[DRAFT — SIGN-OFF]`
**Problem:** IMNCI opens every child assessment with four general danger signs. The current cases jump
straight into module-specific questions, so a generic danger sign can be missed if it doesn't match a
module question.

**Fix:** Add a mandatory **pre-sweep** that runs *before* the module questions for any paediatric case
(Newborn / Infant / Child). Any `হ্যাঁ` → immediate RED, band-locked, skip to referral.

| Pre-sweep ID | Question (BN / EN) | Answers | Logic |
|---|---|---|---|
| GDS-01 | শিশু কি কিছু খেতে বা বুকের দুধ খেতে পারছে না? / Unable to drink or breastfeed at all? | হ্যাঁ · না · নিশ্চিত না | `হ্যাঁ` → RED |
| GDS-02 | যা-ই খাচ্ছে সব বমি করে ফেলছে? / Vomits everything? | হ্যাঁ · না · নিশ্চিত না | `হ্যাঁ` → RED |
| GDS-03 | খিঁচুনি হচ্ছে বা হয়েছে? / Convulsions now or recently? | হ্যাঁ · না · নিশ্চিত না | `হ্যাঁ` → RED |
| GDS-04 | নিস্তেজ, অজ্ঞান, বা ডাকে সাড়া দিচ্ছে না? / Lethargic, unconscious, or not responding? | হ্যাঁ · না · নিশ্চিত না | `হ্যাঁ` → RED |

Referral: FRU / SNCU / DH immediately, call 108. (For a young infant 0–2 m, "unable to feed" includes
"feeding very little / stopped sucking.")

### A2. Uncertainty policy — stop "নিশ্চিত না → GREEN" `[DRAFT — SIGN-OFF]`
**Problem:** Every rule's logic tests only `= হ্যাঁ`. A `নিশ্চিত না` (unsure) on a hard-stop danger-sign
question fires nothing and can land the patient in GREEN. A clinician resolves uncertainty by referring,
not by clearing.

**Proposed rule (committee to pick the exact policy):**
- On any **hard-stop** question, `নিশ্চিত না` → re-prompt once with a plain re-check instruction
  ("look again / ask the family"). If still `নিশ্চিত না`:
  - **Option 1 (recommended, safer):** force minimum **YELLOW** (PHC within 24 h) and **block GREEN** for
    the whole case.
  - **Option 2 (less referral load):** treat as `না` but **block GREEN** — case can be at most "watch +
    follow-up in 2 days," never "all clear."
- **Trade-off:** Option 1 raises YELLOW referral volume at PHC but closes the silent-miss path; Option 2
  keeps volume lower but relies on follow-up. Pick per PHC capacity. Either way, **GREEN must require all
  danger-sign answers to be a clear `না`.**

### A3. Score every answer option, not just `হ্যাঁ` `[DRAFT — SIGN-OFF]`
**Problem:** Answer sets offer intermediate options (`খুব কম`, `কিছুটা`, `একটু`, `অনেক`, `মাঝে মাঝে`,
`একবার`) but per-rule logic ignores them. e.g. NB-001 offers "খুব কম" (feeding very little) — clinically
PSBI — yet logic only fires on `হ্যাঁ`.

**Fix:** Each rule must declare an explicit **answer→band map**. Defaults to standardise:

| Option | Meaning | Default band on a danger-sign question |
|---|---|---|
| হ্যাঁ | Yes | as the rule specifies (usually RED) |
| খুব কম / অনেক / একটু | severe-degree variants | **same band as হ্যাঁ** (a degree of the danger sign) |
| একবার | once (e.g. one convulsion/faint) | **RED** for convulsion/LOC/bleeding questions |
| মাঝে মাঝে / কিছুটা | intermittent / partial | **YELLOW** (not GREEN) |
| না | No | no fire |
| নিশ্চিত না | Unsure | per A2 |

Per-rule overrides are listed in the rule cards where they differ.

### A4. Structured measurement capture `[DRAFT — SIGN-OFF, hardware-dependent]`
**Problem:** RR count, MUAC, temperature, BP, Hb, pad-soak, fetal kick-count are referenced in *actions*
but never captured as numeric inputs that drive the band — so a yes/no proxy stands in for a measurable
fact. Numbers + thresholds are what make triage precise.

**Fix:** Where the ASHA has the device, add a numeric input that the engine thresholds deterministically.
**Confirm device availability for your WB ASHA cohort before enabling** — if a device isn't in the kit,
keep the yes/no proxy and don't ask for the number.

| Input | Device | Deterministic thresholds (to confirm at sign-off) |
|---|---|---|
| Respiratory rate /min | timer/phone | newborn/young-infant ≥60 RED; 2–12 m ≥50; 12 m–5 y ≥40 → pneumonia |
| Temperature °C | digital thermometer | newborn/young-infant: ≥37.5 **or** <35.5 → RED |
| MUAC cm | MUAC tape | <11.5 → SAM/RED; 11.5–12.5 → MAM/YELLOW |
| BP mmHg | BP machine (if in kit) | ≥140/90 → RED (pre-eclampsia) |
| Hb g/dL | Hb meter (if available) | <7 → RED; 7–10.9 → YELLOW (anaemia) |
| Pad soak | count + time | ≥2 pads soaked in 30 min → RED *(proxy still pending per README item #3)* |

### A5. Per-case age / gestational-age intake `[DRAFT — SIGN-OFF]`
**Problem:** Several rules reference age-dependent thresholds ("infant <2 m", "fever <3 m", jaundice
timing) but no question captures exact age, and bleeding in pregnancy is interpreted without trimester.

**Fix:**
- **Newborn/Infant:** capture **age in days/weeks** at intake. Drive young-infant (0–2 m) vs older-infant
  (2–12 m) logic from it (feeding refusal, any fever, and any low temp are RED in 0–2 m).
- **Pregnancy:** capture **gestational age / trimester**. Bleeding 1st trimester → miscarriage/ectopic
  pathway; bleeding ≥20 weeks → placenta praevia/abruption — both RED, but the referral note and
  "no vaginal exam" warning differ.

---

## PART B — Per-module rule changes & additions

Existing rules not listed here are **retained unchanged**. Only corrections and `[NEW]` rules are shown.

### 1. 👶 Newborn Checkup (0–28 days) — `newborn` (HBNC + IMNCI Young Infant)

**Corrections to existing rules:**
- **NB-001** — add answer-map: `খুব কম` (feeding very little) → **RED** (PSBI "very poor feeding"), not silent.
- **NB-006 (jaundice/cyanosis) — split the conflated logic** `[DRAFT — SIGN-OFF]`. Current logic fires RED
  on any `হ্যাঁ` but the note describes a YELLOW day-2–14 path. Replace with a follow-up:
  - n6a: ত্বক/ঠোঁট/জিভ নীলাভ? / bluish skin, lips, or tongue (cyanosis)? → **RED always**.
  - n6b: জন্মের ২৪ ঘণ্টার মধ্যে হলুদ হয়েছে, বা হাতের তালু/পায়ের তলা হলুদ? / jaundice within 24 h of
    birth **or** palms/soles yellow? → **RED**.
  - n6c: হলুদভাব ২–১৪ দিনে, হাতের তালু/পায়ের তলা স্বাভাবিক? / jaundice day 2–14, palms/soles spared? →
    **YELLOW** (PHC within 24 h for bilirubin).

**New rules:**

```
NB-008  RED  HARD-STOP  n8  → SNCU / FRU immediately            [NEW] [DRAFT — SIGN-OFF]
শিশুর শরীর কি ঠান্ডা লাগছে বা স্বাভাবিকের চেয়ে অনেক কম গরম?
Is the baby cold to touch / colder than normal (hypothermia)?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF n8 = হ্যাঁ THEN RED. If thermometer present and temp < 35.5°C THEN RED.
ACTION   PSBI hard-stop. Skin-to-skin/kangaroo warmth + cover head, keep warm during transport.
         Refer SNCU/FRU immediately (≤30 min). Hypothermia is a major neonatal killer.
MAPS TO  cold to touch · low body temperature · temp < 35.5°C · hypothermia
```
```
NB-009  RED  HARD-STOP  n9  → SNCU / FRU immediately            [NEW] [DRAFT — SIGN-OFF]
শিশুর খিঁচুনি হচ্ছে, হাত-পা শক্ত হয়ে যাচ্ছে বা পিছনে বেঁকে যাচ্ছে?
Convulsions, stiffening, or back-arching (opisthotonus)?
ANSWERS  হ্যাঁ · না · একবার · নিশ্চিত না
LOGIC    IF n9 IN [হ্যাঁ, একবার] THEN RED.
ACTION   PSBI hard-stop. Protect airway, left-lateral, do not restrain limbs. Call 108. SNCU/FRU now.
MAPS TO  neonatal seizure · convulsion · stiffening · arching · twitching
```
```
NB-010  RED  HARD-STOP  n10  → FRU / DH                         [NEW] [DRAFT — SIGN-OFF]
ত্বকে অনেক ফুসকুড়ি/পুঁজভরা ফোস্কা, অথবা কান থেকে পুঁজ পড়ছে?
Many skin pustules / pus-filled blisters, or pus draining from ear?
ANSWERS  হ্যাঁ · না · অল্প কয়েকটা · নিশ্চিত না
LOGIC    IF n10 = হ্যাঁ THEN RED. IF n10 = অল্প কয়েকটা (few localised pustules) THEN YELLOW.
ACTION   Many/severe pustules or ear pus = PSBI local infection → FRU/DH. Few localised = PHC within 24 h.
MAPS TO  skin pustules · pus-filled blisters · ear discharge · local bacterial infection
```
```
NB-011  RED  HARD-STOP  n11  → SNCU / FRU immediately           [NEW] [DRAFT — SIGN-OFF]
মাথার নরম অংশ (তালু) ফুলে উঁচু হয়ে আছে?
Is the soft spot on the head (fontanelle) bulging?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF n11 = হ্যাঁ THEN RED.
ACTION   Possible meningitis. Refer SNCU/FRU immediately.
MAPS TO  bulging fontanelle · raised intracranial pressure · meningitis sign
```
> Optional intake flags for HBNC counselling (not RED by themselves): **LBW / preterm** (birth weight
> <2.5 kg or born early) and **did-not-cry-at-birth** history → mark for closer follow-up + extra warmth/
> feeding counselling. Confirm whether these should escalate band at sign-off.

**Newborn band tally after upgrade:** RED 9–10, YELLOW (jaundice split / few pustules) 1–2, GREEN 1.

---

### 2. 🧒 Child Health Check (1–5 years) — `child` (IMNCI + HBYC)

**Corrections:**
- **CH-002 (cough/breathing)** — make the escalation deterministic `[DRAFT — SIGN-OFF]`: add explicit
  follow-ups instead of prose. c2a: বুক ভিতরের দিকে টেনে বসছে (chest indrawing)? → **RED**.
  c2b: শ্বাসে শোঁ-শোঁ আওয়াজ/স্ট্রিডর? → **RED**. RR input (A4): ≥40/min (1–5 y) → YELLOW pneumonia.
- **CH-003 (diarrhoea) → add dehydration sub-assessment** `[DRAFT — SIGN-OFF]`, so the GREEN/YELLOW/RED
  paths described in the action actually exist as logic:
  - c3a: চোখ গর্তে বসে গেছে? / sunken eyes? · c3b: চামড়া টেনে ছাড়লে ধীরে ফিরছে? / skin pinch slow? ·
    c3c: পান করতে পারছে না বা নিস্তেজ? / unable to drink or lethargic?
  - Any of c3a–c3c `হ্যাঁ` → **RED (severe dehydration)**. Restless/irritable + drinks eagerly + some signs
    → **YELLOW (some dehydration)**. None → **GREEN (ORS at home)**.
  - c3d: পায়খানা ১৪ দিনের বেশি? / diarrhoea ≥14 days (persistent)? → **YELLOW**, PHC.

**New rules:**
```
CH-010  RED  HARD-STOP  c7  → FRU / DH immediately              [NEW] [DRAFT — SIGN-OFF]
ঘাড় শক্ত, আলোয় কষ্ট, বা প্রচণ্ড মাথাব্যথা (জ্বরসহ)?
Stiff neck, light sensitivity, or severe headache (with fever)?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF c7 = হ্যাঁ THEN RED.
ACTION   Possible meningitis/encephalitis. Refer FRU/DH immediately, call 108.
MAPS TO  neck stiffness · photophobia · meningitis · encephalitis · severe headache with fever
```
```
CH-011  YELLOW  SCORED  c8  → PHC within 24 h (RED if signs of shock)   [NEW] [DRAFT — SIGN-OFF]
পায়খানার সাথে রক্ত যাচ্ছে?
Is there blood in the stool (dysentery)?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF c8 = হ্যাঁ THEN YELLOW (dysentery → antibiotic at PHC). Escalate RED if severe dehydration
         (link to c3a–c3c) or lethargy.
ACTION   Dysentery needs antibiotics — refer PHC within 24 h. With dehydration/lethargy → FRU.
MAPS TO  blood in stool · dysentery · mucoid bloody diarrhoea
```
```
CH-012  YELLOW  SCORED  c9  → PHC within 24 h (RED if severe pallor)    [NEW] [DRAFT — SIGN-OFF]
হাতের তালু/চোখের পাতা খুব ফ্যাকাশে?
Are palms / inner eyelids very pale (anaemia)?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF c9 = হ্যাঁ THEN YELLOW. Severe palmar pallor → RED.
ACTION   Some pallor → PHC for Hb. Severe pallor → FRU (possible transfusion / severe anaemia).
MAPS TO  pallor · palmar pallor · conjunctival pallor · anaemia
```
> **Measles cross-check (optional YELLOW):** generalised rash + fever + cough/red eyes → flag for
> measles, check Vit-A and immunisation status; corneal clouding or mouth ulcers → RED. Confirm at sign-off.

---

### 3. 👶 Infant Checkup (1–12 months) — `child` (IMNCI + HBYC)

**This module has the most dangerous structural gaps.** Two fixes are mandatory.

**Corrections:**
- **Add age-in-weeks intake (A5)** and split **young infant (0–2 m)** vs **older infant (2–12 m)**:
  - 0–2 m: **any** fever, **any** low temp, **any** feeding refusal → **RED** (PSBI). This makes
    CH-007-i and CH-007 age-correct instead of conflating duration with age.
- **CH-008 (breathing)** — same deterministic split as CH-002: chest indrawing/stridor → RED;
  RR ≥50/min (2–12 m) alone → YELLOW.

**New rules (close the silent-miss holes):**
```
CH-013-i  RED  HARD-STOP  i7  → SNCU / FRU immediately          [NEW] [DRAFT — SIGN-OFF]
শিশু অনেক কম নড়ছে, নিস্তেজ, বা ডাকে/স্পর্শে সাড়া দিচ্ছে না?
Is the infant very lethargic, limp, or not responding to voice/touch?
ANSWERS  হ্যাঁ · না · কিছুটা · নিশ্চিত না
LOGIC    IF i7 = হ্যাঁ THEN RED. IF i7 = কিছুটা (moves only when stimulated) THEN RED in 0–2 m, else YELLOW.
ACTION   Lethargy = severe systemic illness. Refer SNCU/FRU immediately.
MAPS TO  lethargic infant · limp · unresponsive · moves only when stimulated   ⚠ THIS RULE DID NOT EXIST
```
```
CH-014-i  RED  HARD-STOP  i8  → SNCU / FRU immediately          [NEW] [DRAFT — SIGN-OFF]
শিশুর খিঁচুনি হচ্ছে বা হয়েছে?
Convulsions now or recently?
ANSWERS  হ্যাঁ · না · একবার · নিশ্চিত না
LOGIC    IF i8 IN [হ্যাঁ, একবার] THEN RED.
ACTION   Protect airway, left-lateral, call 108, SNCU/FRU now.
MAPS TO  infant seizure · convulsion · fits
```
```
CH-015-i  RED  HARD-STOP  i9  → SNCU / FRU immediately          [NEW] [DRAFT — SIGN-OFF]
শরীর ঠান্ডা (০–২ মাসে) বা মাথার তালু ফুলে উঁচু?
Cold body (in 0–2 m) or bulging fontanelle?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF i9 = হ্যাঁ THEN RED. (Hypothermia in young infant; bulging fontanelle = meningitis.)
ACTION   Warmth + refer SNCU/FRU immediately.
MAPS TO  hypothermia young infant · bulging fontanelle · meningitis sign
```
**Infant band tally after upgrade:** RED 7–8, YELLOW 2–3, plus pre-sweep (A1) in front.

---

### 4. 🤰 Pregnant Mother Checkup — `pregnancy` (MCP + PMSMA)

**Corrections:**
- **ANC-001** — separate the two collapsed concepts so the engine reflects them `[DRAFT — SIGN-OFF]`:
  p1a BP input (A4) ≥140/90 → RED; p1b severe headache → RED; p1c **epigastric / right-upper-abdomen pain**
  (severe pre-eclampsia / HELLP) → **RED** (currently not captured at all).
- **ANC-002 / ANC-006** escalations retained; ensure they are expressed as condition_sets, not prose.

**New rules:**
```
ANC-008  RED  HARD-STOP  p8  → FRU / DH same day (immediately if fainting)  [NEW] [DRAFT — SIGN-OFF]
খুব ফ্যাকাশে, দুর্বল, বা সামান্য পরিশ্রমেই হাঁপিয়ে যাচ্ছেন?
Very pale, weak, or breathless on slight exertion (severe anaemia)?
ANSWERS  হ্যাঁ · না · কিছুটা · নিশ্চিত না
LOGIC    IF p8 = হ্যাঁ THEN RED. IF Hb available and <7 THEN RED; 7–10.9 THEN YELLOW.
         IF p8 = কিছুটা (mild pallor, no breathlessness) THEN YELLOW.
ACTION   Severe anaemia is a leading maternal killer. Severe pallor/breathlessness → FRU/DH for Hb +
         transfusion planning. Mild → PHC for Hb + IFA.
MAPS TO  severe pallor · breathlessness on exertion · palpitations · severe anaemia in pregnancy
```
```
ANC-009  RED  HARD-STOP  p9  → FRU / DH immediately             [NEW] [DRAFT — SIGN-OFF]
জ্বর, বিশেষ করে কাঁপুনি দিয়ে জ্বর আসছে?
Fever, especially with chills/rigors?
ANSWERS  হ্যাঁ · না · মাঝে মাঝে · নিশ্চিত না
LOGIC    IF p9 = হ্যাঁ THEN RED (sepsis/malaria/chorioamnionitis risk in pregnancy).
         IF p9 = মাঝে মাঝে (low-grade, no other sign) THEN YELLOW, PHC within 24 h.
ACTION   High/rigor fever in pregnancy → FRU/DH (rule out malaria, UTI, chorioamnionitis, sepsis).
MAPS TO  fever in pregnancy · rigors · chills · maternal sepsis · malaria
```
```
ANC-010  RED  HARD-STOP  p10  → FRU / DH immediately            [NEW] [DRAFT — SIGN-OFF]
যোনিপথে হঠাৎ জল ভেঙেছে বা ক্রমাগত জল ঝরছে?
Sudden gush or continuous leaking of fluid (PROM)?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF p10 = হ্যাঁ THEN RED. (Preterm: even more urgent.)
ACTION   PROM → infection/preterm-labour risk. No vaginal exam, keep clean pad, refer FRU/DH.
MAPS TO  leaking liquor · rupture of membranes · PROM · watery vaginal discharge
```
> **Optional intake — High-Risk Pregnancy (HRP) flags** (for PMSMA tagging, not necessarily RED alone):
> age <18 or >35, height <145 cm, previous C-section/stillbirth, multiple pregnancy, malpresentation,
> known diabetes/hypertension. Decide band at sign-off; minimum is **YELLOW + PMSMA flag**.
> Note: convulsions/fits in pregnancy are caught by Emergency EM-002 and ANC-006 prodrome.

**Pregnancy band tally after upgrade:** RED 7, YELLOW 2–3, GREEN 1.

---

### 5. 🤱 Postpartum Checkup — `delivery_pnc` (SBA + PPH + PNC)

**Biggest single gap: no eclampsia rule. Postpartum (pre-)eclampsia occurs up to ~6 weeks after delivery.**

**New rules:**
```
PNC-007  RED  HARD-STOP  pp7  → FRU / DH immediately            [NEW] [DRAFT — SIGN-OFF]
প্রসবের পর মাথাব্যথা, চোখে ঝাপসা দেখা, খিঁচুনি, বা রক্তচাপ বেশি?
After delivery: severe headache, blurred vision, convulsions, or high BP?
ANSWERS  হ্যাঁ · না · একবার · নিশ্চিত না
LOGIC    IF pp7 IN [হ্যাঁ, একবার] THEN RED. IF BP available ≥140/90 THEN RED.
ACTION   Postpartum (pre-)eclampsia hard-stop — can occur up to 6 weeks postpartum. Left-lateral,
         protect airway, call 108, FRU/DH immediately. If convulsing & within ANM/MO scope: MgSO4.
MAPS TO  postpartum headache · blurred vision · postpartum convulsion · high BP postpartum · eclampsia
         ⚠ THIS RULE DID NOT EXIST — critical addition
```
```
PNC-008  RED  HARD-STOP  pp8  → FRU / DH immediately            [NEW] [DRAFT — SIGN-OFF]
হঠাৎ শ্বাসকষ্ট, বুকে ব্যথা, বা এক পায়ে ব্যথা/ফোলা?
Sudden breathlessness, chest pain, or pain/swelling in one calf?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF pp8 = হ্যাঁ THEN RED. (Pulmonary embolism / DVT / peripartum cardiomyopathy.)
ACTION   Refer FRU/DH immediately, call 108. Do not let her walk.
MAPS TO  postpartum breathlessness · chest pain · calf swelling · DVT · pulmonary embolism · PPCM
```
```
PNC-009  YELLOW  SCORED  pp9  → PHC / counselling (RED if self-harm thoughts)  [NEW] [DRAFT — SIGN-OFF]
মন খুব খারাপ, কান্না, ঘুম/খাওয়া কমে যাওয়া, বা বাচ্চার প্রতি আগ্রহ নেই?
Persistent low mood, crying, sleep/appetite loss, or no interest in the baby?
ANSWERS  হ্যাঁ · না · মাঝে মাঝে · নিশ্চিত না
LOGIC    IF pp9 = হ্যাঁ THEN YELLOW (postpartum depression screen). Any thought of self-harm or harming
         baby → RED, urgent referral.
ACTION   Counsel, involve family, refer PHC/MO. Self-harm risk → escalate immediately.
MAPS TO  postpartum depression · low mood · anhedonia · self-harm ideation
```
> **Correction — PNC-001 / PNC-002 retained.** Keep the `[SIGN-OFF PENDING]` flag on the "≥2 pads in 30 min"
> proxy (README item #3). Also add a retained-products/urinary-retention check: না-passing urine or
> palpable bladder → YELLOW (FRU if anuria).

**Postpartum band tally after upgrade:** RED 3, YELLOW 6–7.

---

### 6. 💉 Immunization Missed — `immunisation` (UIP National Schedule)

**The schedule content is out of date.** Corrections (verified against current UIP):

- **"MMR" → "MR"** everywhere. India's UIP uses **Measles–Rubella (MR)**, not MMR (no mumps).
  MR-1 at **9–12 months**, MR-2 at **16–24 months**.
- **Add PCV** (Pneumococcal Conjugate): 2 primary doses at **6 & 14 weeks** + **booster at 9–12 months**.
- **Add Rotavirus (RVV):** 3 doses at **6, 10, 14 weeks** (oral).
- **Correct IPV → fIPV:** **two fractional doses at 6 & 14 weeks** (not a single IPV).
- **Vitamin A:** 1st dose at **9 months**; doses 2–9 **six-monthly up to 5 years**.
- **PCV/RVV rollout:** now part of national UIP; **confirm current West Bengal rollout/stock status** with
  the State Immunization Officer before wording catch-up advice (district variation possible).

**Corrected reference schedule (for IMM-002 / catch-up logic):**

| Age | Vaccines (current UIP) |
|---|---|
| Birth | BCG, OPV-0, Hep-B birth dose |
| 6 weeks | OPV-1, Pentavalent-1, RVV-1, fIPV-1, PCV-1 |
| 10 weeks | OPV-2, Pentavalent-2, RVV-2 |
| 14 weeks | OPV-3, Pentavalent-3, RVV-3, fIPV-2, PCV-2 |
| 9–12 months | MR-1, JE-1 (endemic), PCV-booster, Vitamin A-1 |
| 16–24 months | MR-2, JE-2 (endemic), DPT-booster-1, OPV-booster, Vitamin A 2-9 (6-monthly) |
| 5–6 years | DPT-booster-2 |
| 10 & 16 years | TT/Td |
| Pregnant woman | TT/Td (1 dose if vaccinated within 3 years) |

**Rule logic retained**, with one fix and one addition:
- **IMM-001 logic gap:** currently `IF im1 IN [0–6 m, 6–12 m] THEN YELLOW` — make the 1–5 y branch
  explicitly route to IMM-003 (booster catch-up) so older children aren't dropped.
- **New IMM-006 `[NEW]`:** AEFI history — "আগের টিকার পর কি গুরুতর প্রতিক্রিয়া হয়েছিল?" / severe reaction
  after a previous dose? `হ্যাঁ` → **YELLOW + refer MO before next dose** (do not auto-schedule).
- Keep the core counselling: **do not restart the series**; give the missed dose and continue. BCG up to 1 y.

**Immunization band tally:** YELLOW 5–6 (no RED needed — sick-child danger signs route through Child/Infant
+ pre-sweep). IMM-004 correctly defers vaccination for moderate/severe illness.

---

### 7. 🚨 Emergency Case — `emergency` (Global Emergency Rule Engine)

**Module is thin and missing common rural killers in WB.** Retain EM-001..005; add:

```
EM-006  RED  HARD-STOP  e6  → FRU / DH ≤ 30 min, call 108       [NEW] [DRAFT — SIGN-OFF]
সাপে কামড়েছে, বিষাক্ত পোকা বা পশুর কামড়?
Snakebite, venomous sting, or animal bite?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF e6 = হ্যাঁ THEN RED — band locked.
ACTION   Immobilise the limb (splint), keep it below heart level, remove tight items, DO NOT cut/suck/
         tourniquet. Call 108, FRU/DH ≤30 min (anti-snake-venom). Note bite time. Dog/animal bite → also
         wound wash 15 min + ARV/RIG at facility.
MAPS TO  snakebite · scorpion sting · dog bite · rabies risk · envenomation
```
```
EM-007  RED  HARD-STOP  e7  → FRU / DH ≤ 30 min, call 108       [NEW] [DRAFT — SIGN-OFF]
বিষ/কীটনাশক/অতিরিক্ত ওষুধ খেয়েছে বা খাওয়ানো হয়েছে?
Poison, pesticide, or overdose ingested?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF e7 = হ্যাঁ THEN RED — band locked.
ACTION   Do NOT induce vomiting. Bring the container/label. Protect airway, left-lateral if drowsy.
         Call 108, FRU/DH ≤30 min.
MAPS TO  poisoning · pesticide ingestion · OP poisoning · drug overdose
```
```
EM-008  RED  HARD-STOP  e8  → FRU / DH ≤ 30 min, call 108       [NEW] [DRAFT — SIGN-OFF]
ঠান্ডা-ঘামে ভেজা, খুব দুর্বল নাড়ি, অত্যন্ত নিস্তেজ (শকের লক্ষণ)?
Cold clammy skin, very weak pulse, extreme listlessness (shock)?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF e8 = হ্যাঁ THEN RED — band locked.
ACTION   Lay flat, keep warm, raise legs, nothing by mouth. Call 108, FRU/DH ≤30 min.
MAPS TO  shock · cold extremities · thready pulse · circulatory collapse
```
```
EM-009  RED  HARD-STOP  e9  → FRU / DH ≤ 30 min, call 108       [NEW] [DRAFT — SIGN-OFF]
গুরুতর আঘাত, বড় ক্ষত থেকে রক্তপাত, বা মারাত্মক পোড়া?
Major injury, bleeding from a large wound, or severe burn?
ANSWERS  হ্যাঁ · না · নিশ্চিত না
LOGIC    IF e9 = হ্যাঁ THEN RED — band locked.
ACTION   Direct pressure on bleeding; for burns cool with clean water, cover, do not apply substances.
         Immobilise suspected fractures. Call 108, FRU/DH ≤30 min.
MAPS TO  trauma · road accident · major laceration · severe burn · fracture with bleeding
```
> **Obstetric-emergency add (confirm placement — Emergency vs ANC) `[DRAFT — SIGN-OFF]`:** in labour with
> cord visible at the vagina (**cord prolapse**) or labour >12–18 h with no progress (**obstructed
> labour**) → RED, FRU immediately, knee-chest position for cord prolapse. **Newborn not breathing at
> birth** → RED + stimulate/clear airway/bag-mask if trained while transport is arranged.

EM-005 re-sweep invariant **retained as-is** — it is the correct global safety lock.

---

## PART C — Master index of additions (for the committee)

| Module | New / changed | ID | Band | Why |
|---|---|---|---|---|
| All paeds | NEW | GDS-01..04 | RED | IMNCI general danger-sign pre-sweep |
| Newborn | NEW | NB-008 | RED | Hypothermia (PSBI) — was missing |
| Newborn | NEW | NB-009 | RED | Convulsions — was missing |
| Newborn | NEW | NB-010 | RED/Y | Skin pustules / ear pus |
| Newborn | NEW | NB-011 | RED | Bulging fontanelle |
| Newborn | FIX | NB-006 | RED/Y | Split cyanosis vs day-2–14 jaundice |
| Child | NEW | CH-010 | RED | Meningitis (stiff neck) |
| Child | NEW | CH-011 | Y/RED | Dysentery (blood in stool) |
| Child | NEW | CH-012 | Y/RED | Pallor / anaemia |
| Child | FIX | CH-002/003 | — | Make escalations deterministic; dehydration sub-assessment |
| Infant | NEW | CH-013-i | RED | Lethargy/movement — **was missing entirely** |
| Infant | NEW | CH-014-i | RED | Convulsions — was missing |
| Infant | NEW | CH-015-i | RED | Hypothermia / fontanelle |
| Infant | FIX | age split | — | 0–2 m vs 2–12 m thresholds |
| Pregnancy | NEW | ANC-008 | RED/Y | Severe anaemia — was missing |
| Pregnancy | NEW | ANC-009 | RED/Y | Fever / sepsis — was missing |
| Pregnancy | NEW | ANC-010 | RED | PROM / leaking liquor — was missing |
| Pregnancy | FIX | ANC-001 | RED | Add epigastric pain (HELLP); separate BP/headache |
| Postpartum | NEW | PNC-007 | RED | **Postpartum eclampsia — was missing** |
| Postpartum | NEW | PNC-008 | RED | PE / DVT / cardiomyopathy |
| Postpartum | NEW | PNC-009 | Y/RED | Postpartum depression screen |
| Immunisation | FIX | schedule | — | MR not MMR; add PCV, RVV, fIPV×2, Vit-A; WB rollout |
| Immunisation | NEW | IMM-006 | Y | AEFI history |
| Emergency | NEW | EM-006..009 | RED | Snakebite/bite, poisoning, shock, trauma/burns |

---

## PART D — Implementation notes (engineering)

These are JSON/engine changes implied by the rules above. I've kept them descriptive rather than
shipping merge-ready JSON, because (a) the rules must clear clinical sign-off first, and (b) I don't have
your exact `clinical_decision_engine.json` field schema in front of me.

1. **Answer→band map per rule.** Add an explicit `answer_band_map` to every rule object so intermediate
   options (`খুব কম`, `কিছুটা`, `একবার`, …) resolve to a band. Today only `= হ্যাঁ` is honoured.
2. **Uncertainty handling (A2).** Add a `uncertain_policy` field at engine level + a `green_blocked` flag
   that any `নিশ্চিত না` on a hard-stop sets. GREEN resolution must check `green_blocked == false`.
3. **Escalation sub-questions (A3).** Convert prose escalations into real child questions with their own
   `condition_set` → band, so the path is deterministic and traceable.
4. **Measurement inputs (A4).** Add numeric-input question types (`type: "numeric"`, `unit`, `thresholds`)
   gated by a per-cohort `device_available` config. If false, fall back to the yes/no proxy.
5. **Age/GA intake (A5).** Add `age_days` (paeds) and `gestational_weeks` (pregnancy) at case entry; let
   rules read them in `condition_set`.
6. **Pre-sweep ordering.** GDS-01..04 must evaluate before module rule 1 and obey the same first-hard-stop
   exit + band-lock + re-sweep invariant (EM-005). Re-sweep must re-check pre-sweep too.
7. **Versioning.** Cut `clinical_decision_engine.json` → v1.1.0 (logic: answer-maps, uncertainty,
   escalations, pre-sweep) and `triage_cases.json` → v3.0.0 (new questions/rules). Keep a `signoff` block
   per rule: `{ status: "draft" | "approved", approver, date, protocol_ref }`. The app should be able to
   **refuse to load any rule whose `status != "approved"`** in production — so drafts can't ship by accident.
8. **Decision-trace fields.** For MDSR defensibility, log per case: every question, answer, the rule(s)
   fired, the band, timestamp, engine+cases version, and which signed-off rule version was active.

---

## SIGN-OFF CHECKLIST (AIIH&PH / Secretariat clinical committee)

For each `[DRAFT — SIGN-OFF]` item, the committee confirms: ✅ clinically correct · ✅ correct band ·
✅ correct referral target · ✅ Bengali wording is accurate and plain · ✅ within ASHA scope (recognition +
referral; any treatment step like MgSO4/misoprostol is ANM/MO scope unless explicitly delegated).

Specific decisions needed:
- [ ] Uncertainty policy: **Option 1 (force YELLOW)** vs **Option 2 (block GREEN only)** — per PHC capacity.
- [ ] Which **measurement devices** are actually in the WB ASHA kit (enables A4 numeric thresholds).
- [ ] WB-specific **PCV / Rotavirus rollout** status and any district JE endemicity.
- [ ] Exact **fever/temperature and Hb thresholds** for confirmation.
- [ ] PPH **"≥2 pads in 30 min"** proxy (carried over, still open — README item #3).
- [ ] Placement of obstetric emergencies (cord prolapse / obstructed labour / birth asphyxia): Emergency
      module vs ANC/PNC.
- [ ] Native-Bengali clinical review of all new question strings.

---

*Drafted as a proposed upgrade to the tracked AshaMitra rule files. Bands unchanged: 🟢 Green = home care ·
🟡 Yellow = PHC within 24 h · 🔴 Red = FRU/SNCU/DH immediately (≤30–60 min), call 108. A fired RED can never
be downgraded (re-sweep invariant). No item here is clinically validated until signed off.*
