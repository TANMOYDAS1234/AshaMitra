# MCP Card — Digitalisation Spec (canonical)

Source: the full **Mother & Child Protection Card (এমসিপি কার্ড), 2018 ed.** (44-page
NHM card the ASHA maintains). This is the single source of truth for the
"digital MCP card". **Field order and Bengali wording below mirror the paper card
so a worker can tick down the screen exactly as they tick the card.**

> ⚠️ Version note: the supplied PDF is the **Assam** print; the worker's physical
> card (her photos) is the **West Bengal** print. They differ only in the ANC
> exam table — the WB card adds the **TB-screening rows + body-swelling +
> E-PMSMA dates** (marked `[WB]` below). The digital card follows the **WB
> superset** (her actual card). Everything else is identical.

Legend: 🟢 already in app · 🟡 partial · 🔴 to build.

---

## A. Schemes & rights (card pp.1–2) — info cards
JSY (cash for institutional delivery) · PMMVY (1st living child, instalments) ·
PMSMA (free check on the 9th, 2nd/3rd trimester) · JSSK (free delivery/CS/drugs/
tests/blood/transport/diet; sick infant <1yr) · sex-determination is illegal.
🟡 (some surfaced in deck; not in app)

## B. Family & mother registration (p.3) — maps to patient registration 🟡
Photo slot ("এখানে শিশুর ছবি লাগান") · **গর্ভবতীটি কি উচ্চ ঝুঁকিপূর্ণ? হ্যাঁ/না**
- মায়ের নাম · বয়স · বাবার নাম · ঠিকানা · মায়ের মোবাইল · বাবার মোবাইল
- MCTS / RCH / নিবন্ধন নং (মা) · PMMVY যোগ্য হ্যাঁ/না · ব্যাঙ্ক+শাখা · A/C নং · IFSC
- **গর্ভাবস্থার তথ্য:** গর্ভসঞ্চার সংখ্যা / পূর্ববর্তী জীবিত প্রসব · সর্বশেষ প্রসবের স্থান · **LMP** · **EDD** · চিহ্নিত প্রসব কেন্দ্র · ফলাফল (জীবিত/মৃত)
- **জন্মের রেকর্ড:** বাচ্চার নাম · DOB · জন্মের সময় · প্রসবের স্থান · ছেলে/মেয়ে · জন্ম নিবন্ধন নং · MCTS/RCH · JSY নথিভুক্তি নং · JSY ভাতা টাকা+তারিখ
- **প্রতিষ্ঠান:** AWC + LGD কোড · AWC নং · GP/ADC village/ward · postal · ASHA · ANM/MPW · হাসপাতাল ফোন · SH/DH/SDH/CHC/PHC + জেলা · উপকেন্দ্র নিবন্ধন+তারিখ · স্বাস্থ্য পুষ্টি দিবস · রেফারেল হাসপাতাল · **শিশুর আধার · মায়ের আধার** · ASHA মোবাইল · ambulance toll-free

## C. ANC tracker & schedule (p.4) — maps to due-list/schedule 🟡
Urine pregnancy test (হ্যাঁ/না + date) · registration in first 3 months · **≥4 ANC** ·
BP+blood+urine each visit · weight each visit (gain 9–11 kg) · **TD/Td ×2** (or 1
booster if dose in last 3 yr) · **IFA daily + Calcium ×2 daily** after 1st trimester
(≥180 IFA, ≥360 Ca) · **Albendazole 400 mg ×1** after 1st trimester · care advice
(varied/fortified food, eat ¼ more, AWC nutrition, brush 2×, 8 h sleep + 2 h rest,
iodised/double-fortified salt).

## D. ANC examination record (p.5) — THE capture screen 🟡→🔴 (priority)
**One-time (at registration):**
- পূর্বের গর্ভাবস্থায় জটিলতা ✓: APH · Eclampsia · PIH · Anaemia · Obstructed labour · PPH · LSCS · Congenital anomaly · Abortion · Others
- পূর্বের ইতিহাস ✓: যক্ষা(TB) · উচ্চ রক্তচাপ · হৃদরোগ · ডায়াবেটিস · হাঁপানি · অন্যান্য
- পরীক্ষা: উচ্চতা(সেমি) · হৃদপিণ্ড · ফুসফুস · স্তন (স্তনবৃন্ত ভিতরে ঢুকে আছে কিনা)
- ব্লাড গ্রুপ ও RH টাইপিং (+তারিখ)

**Per-visit ANC table — EXACT order (cols ১–৫):**
1. তারিখ  2. গর্ভের ক্রমের বয়স (সপ্তাহ)  3. ওজন (কেজি)  4. নাড়ির গতি  5. রক্তচাপ
6. ফ্যাকাসে ভাব  7. ফুলে যাওয়া  8. জন্ডিস  9. অন্যান্য সমস্যা
10. কাশি/জ্বর (২ সপ্তাহের বেশি) `[WB-TB]`  11. ওজন না বাড়া (গত ৩ মাসে) `[WB-TB]`
12. রাত্রে ঘাম হওয়া `[WB-TB]`  13. শরীরে কোথাও ফোলা ভাব `[WB]`
14. E-PMSMA অতিরিক্ত ANC — ১ম/২য়/৩য় তারিখ `[WB]`

**তলপেট পরীক্ষা:** জরায়ুর উচ্চতা (সপ্তাহ/সেমি) · ভ্রূণের অবস্থান Lie/Presentation ·
ভ্রূণের নড়াচড়া (স্বাভাবিক/কম/নেই) · FHR /মিনিট · যোনিপথ P/V (যদি করা হয়)

**আবশ্যিক পরীক্ষা:** হিমোগ্লোবিন(গ্রাম) · মূত্রের এলবুমিন · মূত্রের শর্করা · HIV · সিফিলিস ·
আল্ট্রাসোনোগ্রাফি (হ্যাঁ/না) · গর্ভাবস্থাকালীন ডায়াবিটিস (GDM)

**অন্যান্য পরীক্ষা (+তারিখ):** TSH · HBsAg · রক্তের শর্করা · অন্যান্য

## E. Danger signs & delivery (p.6) — maps to triage 🟢
Bleeding (during/after) · breathlessness / severe anaemia · high fever within a
month · headache + blurred vision + whole-body swelling · labour pain before time /
>12 h / reduced fetal movement · water breaks before 37 wk → **go to hospital now**.
Institutional delivery; emergency transport prep; 48 h post-delivery stay; BF within 1 h.

## F. Postpartum (p.7) — maps to PNC/HBNC capture 🔴
**Delivery record:** date · place · type (normal/assisted/CS) · live/still · timing ·
admission duration · complications · baby sex · **baby weight (kg+g)** · cried at birth
(হ্যাঁ/না) · BF within 1 h (হ্যাঁ/না) · Vitamin K injection (হ্যাঁ/না) · mother IFA 6 mo + Calcium 6 mo.
**মায়ের প্রসব-পরবর্তী যত্ন (cols: ১ম/৩য়/৫ম দিন · ৬ষ্ঠ সপ্তাহ):** কোনো সমস্যা · ফ্যাকাসে ভাব ·
নাড়ির গতি · রক্তচাপ · শরীরের তাপমাত্রা · স্তন (স্বাভাবিক/ফোলা/শক্ত) · স্তনবৃন্ত (ফাটা/স্বাভাবিক) ·
জরায়ুতে চাপে ব্যথা (আছে/নেই) · যোনিপথ রক্তস্রাব (অতিরিক্ত/স্বাভাবিক) · যোনিপথ স্রাব (স্বাভাবিক/দুর্গন্ধ) ·
এপিসিওটমি/tear (সুস্থ/সংক্রমণ) · পরিবার পরিকল্পনা পরামর্শ (হ্যাঁ/না) · অন্যান্য জটিলতা+রেফারেল.
**শিশুর যত্ন (same cols):** ওজন · প্রস্রাব · মলত্যাগ · ডায়রিয়া · বমি · খিঁচুনি · নড়াচড়া (স্বাভাবিক/কম) ·
দুধ টানা (স্বাভাবিক/কম) · শ্বাস (দ্রুত/কষ্টকর) · বুকের খাঁচা ভিতরে (হ্যাঁ/না) · তাপমাত্রা · জন্ডিস · নাভির অবস্থা.

## G. Newborn + 6wk–5yr child checklist (p.8) — HBNC/HBYC 🟡
Newborn danger signs (can't suck/BF · convulsions · breathing 60+/min · chest
indrawing · axillary >37.5°C or <35.5°C · no movement). **HBYC by 3/6/9/12/15 mo:**
sick? · BF? · complementary-feeding amounts · AWC weighing · developmental delay ·
immunisation · MR given · Vit-A given · ORS at home · IFA syrup at home + services.

## H. Diarrhoea & pneumonia (p.9) 🟢  ORS + Zinc ×14 d; fast-breathing thresholds by age.

## I. IYCF + development milestones (pp.10–25) 🔴
Feeding by age (0–6 mo exclusive BF; 6 mo–2 yr complementary). **Milestone ✓-lists +
"danger" developmental signs** at 2–3 mo, 3 mo, 4–6 mo, 6 mo, 7–9 mo, 9 mo, 10–12 mo,
12 mo, 18 mo, 24 mo, 3 yr. → a per-age milestone tracker.

## J. Family planning (p.26) — info 🔴  IUCD/Antara/Chhaya/condom/sterilisation.

## K. IFA syrup + deworming tracker (p.27) 🔴
6 mo–5 yr: IFA syrup 2×/week (Mon+Thu), bottles 1–10 by month; Albendazole 1st/2nd dose by age band.

## L. WHO growth charts (pp.28–35) — growth monitoring 🔴
Weight-for-age + weight-for-height, girl & boy, birth–3 yr & 3–5 yr (green/yellow/orange bands).

## M. Immunisation (pp.36–40) — maps to vaccine visits 🟡
Schedule + record by age: birth · 1½ · 2½ · 3½ · 9 · 16–24 mo · 5–6 · 10 · 16 yr; missed-dose
catch-up; full/complete-immunisation status. **Antigens (p.38):** BCG · HepB · OPV(0/1/2/3+booster) ·
IPV · Penta(1/2/3) · PCV(1/2/booster) · Rota(1/2/3) · MR(1/2) · JE(1/2) · DPT booster.

---
### Build order (proposed)
1. **D — ANC capture to exact MCP parity** (+ patient photo on the screen) ← her priority.
2. **F — PNC + newborn day-1/3/5/6wk tables** (HBNC capture).
3. **B — registration field parity** (LMP/EDD, high-risk flag, bank/Aadhaar, institution).
4. **K + L + I** — IFA/deworming tracker, growth charts, milestone tracker.
M (immunisation) and E/H (triage) already largely exist — align wording/sequence.
