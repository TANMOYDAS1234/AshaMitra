# ASHAMitra — Clinical Modules (detailed)

> Auto-generated from [`assets/data/asha_engine.json`](../assets/data/asha_engine.json) — engine `asha_cdss_engine_v2` **v2.6.0-guideline-aligned**.
> Companion docs: [11-step pipeline](PIPELINE.md) · [sign-off rules](SIGNOFF_RULES.md) · [overview + backend](MODULES_REFERENCE.md).

**How to read a rule type:** *hard-stop* = one matching answer alone → RED · *combination* = all listed answers together → the shown band · *numeric* = a measured vital crossing the limit · *yellow* = a single smaller worry → YELLOW · *score* = points added per positive answer.
Rules marked **†** are flagged `clinical_sign_off_pending` (live, but awaiting clinician sign-off — see [SIGNOFF_RULES.md](SIGNOFF_RULES.md)).
Unsure about a medical word? See the **[plain-words glossary](#-glossary-medical-words-in-plain-language)** at the bottom.

**Bands:** 🟢 home care · 🟡 refer PHC within 24 h · 🔴 refer FRU/SNCU/DH now (ambulance 108).

---

## 🟢 In easy words
A **module is a checklist for one type of patient.** The app picks the right one (newborn, child, pregnant woman, etc.), asks a few yes/no questions, looks at a few measurements, and gives a colour: 🟢 fine · 🟡 see a clinic · 🔴 emergency.

Each checklist mixes five kinds of rules:
- **Hard-stop** — one dangerous "yes" alone → 🔴 RED (no debate).
- **Combination** — two worries *together* that are dangerous as a pair.
- **Numeric** — a *measured* number crossing a safe limit (e.g. oxygen below 90%).
- **Yellow** — a smaller worry → 🟡 see a clinic.
- **Score** — small worries add up points; enough points raises the level.

Everything below is just those five ingredients filled in for each type of patient. The strictness changes by patient: a **newborn** turns almost every sign into 🔴 RED (babies get sick fast), while **immunisation** and **development** never go past 🟡 YELLOW.

---

## 🍼 Newborn Checkup (0–28 days) — `newborn`
*নবজাতক চেকআপ (০-২৮ দিন)*

**Who:** Baby 0–28 days  
**Purpose:** Built around **PSBI (Possible Serious Bacterial Infection)**. Newborns deteriorate within hours, so the list is the strictest in the app — almost every danger sign is an immediate RED referral to a newborn special-care unit (SNCU) or first-referral unit (FRU).  
**🟢 In easy words:** A baby less than one month old. Newborns can go from fine to very sick in just hours, so nearly every warning sign here means **"rush to a hospital with newborn care now."**

### Questions (14)

| ID | Question |
|---|---|
| `n1` | Is the baby unable to breastfeed? |
| `n2` | Does the baby have fever? |
| `n3` | Is breathing fast or difficult? |
| `n4` | Is the navel red, swollen, or has pus? |
| `n5` | Is the baby lethargic or not moving? |
| `n6` | Does the skin look yellow or bluish? |
| `n7` | Has the baby had convulsions or abnormal movements? |
| `n8` | Is the baby cold to touch / colder than normal (hypothermia)? |
| `n9` | Many skin pustules / pus-filled blisters, or pus draining from ear? |
| `n10` | Is the soft spot on the head (fontanelle) bulging? |
| `n11` | Has the baby NOT passed stool in the first 24 h, or NOT passed urine in the first 48 h? |
| `n12` | Does the baby have loose stools / diarrhoea? |
| `n13` | Are the baby's eyes red, swollen, or draining pus? |
| `n14` | Does the baby have a visible congenital defect (e.g. cleft lip/palate, abnormal limb)? |

### Hard-stop rules → 🔴 RED (13)

| Rule | Trigger (answer = yes) | Refer to | Suspected condition |
|---|---|---|---|
| `NB-001` | Is the baby unable to breastfeed? | SNCU / FRU immediately | Possible neonatal sepsis |
| `NB-002` | Does the baby have fever? | SNCU / FRU immediately | Neonatal fever / sepsis |
| `NB-003` | Is breathing fast or difficult? | SNCU / FRU immediately | Respiratory distress |
| `NB-004` | Is the navel red, swollen, or has pus? | FRU / DH immediately | Omphalitis |
| `NB-005` | Is the baby lethargic or not moving? | SNCU / FRU immediately | Possible neonatal sepsis |
| `NB-006` | Does the skin look yellow or bluish? | SNCU / FRU immediately | Jaundice / Cyanosis |
| `NB-007` | Has the baby had convulsions or abnormal movements? | SNCU / FRU immediately | Neonatal seizures, Possible sepsis / meningitis |
| `NB-008` † | Is the baby cold to touch / colder than normal (hypothermia)? | SNCU / FRU immediately | Neonatal hypothermia |
| `NB-010` † | Many skin pustules / pus-filled blisters, or pus draining from ear? | FRU / DH immediately | Local bacterial infection (PSBI) |
| `NB-011` † | Is the soft spot on the head (fontanelle) bulging? | SNCU / FRU immediately | Meningitis |
| `NB-012` | Has the baby NOT passed stool in the first 24 h, or NOT passed urine in the first 48 h? | FRU / SNCU immediately | Intestinal/urinary obstruction or serious neonatal illness |
| `NB-013` | Does the baby have loose stools / diarrhoea? | FRU / SNCU immediately | Neonatal diarrhoea / dehydration |
| `NB-014` | Are the baby's eyes red, swollen, or draining pus? | FRU / DH immediately | Ophthalmia neonatorum |

### Combination rules (5)

| Rule | If ALL of these are yes | Band | Suspected condition |
|---|---|---|---|
| `NB-COMB-001` | n2 (Does the baby have fever?) **+** n3 (Is breathing fast or difficu) | 🔴 RED | Severe PSBI |
| `NB-COMB-002` † | n6 (Does the skin look yellow or) **+** n1 (Is the baby unable to breast) | 🔴 RED | Severe jaundice / kernicterus risk |
| `NB-COMB-003` † | n5 (Is the baby lethargic or not) **+** n3 (Is breathing fast or difficu) | 🔴 RED | Severe neonatal sepsis |
| `NB-COMB-004` † | n4 (Is the navel red, swollen, o) **+** n2 (Does the baby have fever?) | 🔴 RED | Omphalitis with systemic sepsis |
| `NB-COMB-005` † | n1 (Is the baby unable to breast) **+** n2 (Does the baby have fever?) | 🔴 RED | Possible serious bacterial infection (PSBI) |

### Numeric (vital) rules (9)

| Rule | Vital | Condition | Band | Meaning |
|---|---|---|---|---|
| `NB-VITAL-001` | `spo2` | < 90 | 🔴 RED | SpO2 < 90% — critical hypoxia. |
| `NB-VITAL-002` | `respiratory_rate` | ≥ 60 | 🔴 RED | RR ≥ 60/min — severe tachypnoea. |
| `NB-VITAL-003` | `temperature_c` | ≥ 37.5 | 🔴 RED | Temp ≥ 37.5°C — danger sign in newborn. |
| `NB-VITAL-004` | `weight_kg` | < 1.5 | 🔴 RED | Weight < 1.5 kg — VLBW. Start KMC, refer SNCU immediately. |
| `NB-VITAL-005` † | `temperature_c` | < 35.5 | 🔴 RED | Temp < 35.5°C — hypothermia. Start kangaroo mother care, refer SNCU. |
| `NB-VITAL-006` † | `heart_rate` | > 180 | 🔴 RED | HR > 180/min — severe tachycardia. Refer SNCU. |
| `NB-VITAL-007` † | `weight_kg` | 1.8–2.5 | 🟡 YELLOW | Weight 1.8–2.5 kg — LBW. KMC, breastfeed every 2 h. |
| `NB-VITAL-008` † | `weight_kg` | < 1.8 | 🔴 RED | Weight < 1.8 kg — HBNC referral threshold. KMC + expressed breast milk + refer SNCU. |
| `NB-VITAL-009` † | `temperature_c` | 35.5–36.4 | 🟡 YELLOW | Temp 35.5–36.4°C — cold stress. KMC, warm the room, recheck in 1 hour. |

### Yellow rules → 🟡 YELLOW (1)

| Rule | Trigger | Refer to | Suspected |
|---|---|---|---|
| `NB-Y-001` | Does the baby have a visible congenital defect (e.g. cleft lip/palate, abnormal limb)? | PHC / DH for assessment | Congenital anomaly |

### Risk score
**Weights:** n1 = 3 · n2 = 2 · n3 = 3 · n4 = 2 · n5 = 3 · n6 = 2 · n7 = 3 · n8 = 3 · n9 = 2 · n10 = 3  
**Bands by score:** 🟢 GREEN 0–2 · 🟡 YELLOW 3–5 · 🔴 RED 6–100

---

## 🧒 Child Health Check (2 months–5 years) — `child`
*শিশু স্বাস্থ্য যাচাই (২ মাস–৫ বছর)*

**Who:** Child 2 months–5 years  
**Purpose:** Follows the **IMNCI** approach. Screens for the leading under-5 killers: pneumonia, diarrhoea/dehydration, prolonged fever (malaria/dengue/typhoid), severe acute malnutrition, and meningitis/sepsis danger signs.  
**🟢 In easy words:** A small child (2 months–5 years). Looks for the things that most often kill young children — chest infection, dehydration from diarrhoea, long fevers, and severe thinness — plus emergency signs like fits.

### Questions (13)

| ID | Question |
|---|---|
| `c1` | Has fever lasted more than 5 days? |
| `c2` | Is there cough or breathing difficulty? |
| `c3` | Is there diarrhoea or repeated vomiting? |
| `c4` | Is the child completely refusing to eat? |
| `c5` | Signs of dehydration — sunken eyes, dry lips? |
| `c6` | Is weight much less than expected for age? |
| `c7` | Has the child had convulsions or fits? |
| `c8` | Is the child abnormally sleepy, lethargic, or unconscious? |
| `c9` | Does the child vomit everything? |
| `c10` | Stiff neck, light sensitivity, or severe headache with fever? |
| `c11` | Is there blood in the stool (dysentery)? |
| `c12` | Are the palms or inner eyelids very pale (anaemia)? |
| `c13` | Lower chest indrawing, or stridor at rest? |

### Hard-stop rules → 🔴 RED (8)

| Rule | Trigger (answer = yes) | Refer to | Suspected condition |
|---|---|---|---|
| `CH-001` | Has fever lasted more than 5 days? | PHC / DH same day | Prolonged fever — malaria / typhoid / dengue |
| `CH-005` | Signs of dehydration — sunken eyes, dry lips? | FRU immediately | Severe dehydration |
| `CH-007` | Has the child had convulsions or fits? | FRU / DH immediately | Seizure, Meningitis / cerebral malaria |
| `CH-008` | Is the child abnormally sleepy, lethargic, or unconscious? | FRU / DH immediately | Severe systemic illness, Shock / sepsis |
| `CH-009` † | Does the child vomit everything? | FRU / DH immediately | Unable to retain feeds, Possible serious illness |
| `CH-010` † | Stiff neck, light sensitivity, or severe headache with fever? | FRU / DH immediately | Meningitis, Encephalitis |
| `CH-004` † | Is the child completely refusing to eat? | FRU / DH immediately | Very severe disease, Feeding refusal |
| `CH-013` † | Lower chest indrawing, or stridor at rest? | FRU / DH immediately | Severe pneumonia / very severe disease |

### Combination rules (4)

| Rule | If ALL of these are yes | Band | Suspected condition |
|---|---|---|---|
| `CH-COMB-001` | c2 (Is there cough or breathing ) **+** c5 (Signs of dehydration — sunke) | 🔴 RED | Severe pneumonia with dehydration |
| `CH-COMB-002` † | c1 (Has fever lasted more than 5) **+** c2 (Is there cough or breathing ) | 🔴 RED | Pneumonia, Malaria |
| `CH-COMB-003` † | c3 (Is there diarrhoea or repeat) **+** c4 (Is the child completely refu) | 🔴 RED | Severe dehydration with feeding refusal |
| `CH-COMB-004` † | c3 (Is there diarrhoea or repeat) **+** c5 (Signs of dehydration — sunke) | 🔴 RED | Severe dehydration (IMNCI Plan C) |

### Numeric (vital) rules (10)

| Rule | Vital | Condition | Band | Meaning |
|---|---|---|---|---|
| `CH-VITAL-001` | `spo2` | < 90 | 🔴 RED | SpO2 < 90% — critical hypoxia. |
| `CH-VITAL-002` | `muac_cm` | < 11.5 | 🔴 RED | MUAC < 11.5 cm = SAM. Refer NRC. |
| `CH-VITAL-003` | `muac_cm` | 11.5–12.5 | 🟡 YELLOW | MUAC 11.5–12.5 cm = MAM. Refer ICDS. |
| `CH-VITAL-004` † | `respiratory_rate` | ≥ 50 | 🔴 RED | RR ≥ 50/min (2 mo–1 y) = severe pneumonia. Refer FRU. |
| `CH-VITAL-005a` † | `temperature_c` | ≥ 40 | 🔴 RED | Temp ≥ 40°C = hyperpyrexia. Refer FRU, test for malaria. |
| `CH-VITAL-005b` † | `temperature_c` | 39–40 | 🟡 YELLOW | Temp 39–40°C = high fever. Refer PHC, give paracetamol. |
| `CH-VITAL-006` † | `weight_for_age_z` | < -3 | 🔴 RED | WFA Z-score < -3 = severe underweight. Refer NRC. |
| `CH-VITAL-006b` † | `weight_for_age_z` | -3–-2 | 🟡 YELLOW | WFA Z-score -3 to -2 = moderate underweight (MAM). Refer ICDS/Anganwadi for supplementary nutrition, weigh monthly. (MCP card: yellow zone, pg 28–31) |
| `CH-VITAL-007` † | `respiratory_rate` | ≥ 40 | 🟡 YELLOW | RR ≥ 40/min (child 1–5 y) = possible pneumonia. Refer PHC within 24 h. Chest indrawing = RED. |
| `CH-VITAL-008` † | `spo2` | 90–94 | 🟡 YELLOW | SpO2 90–94% = moderate hypoxia. Keep the child calm and upright, refer to PHC promptly. |

### Yellow rules → 🟡 YELLOW (5)

| Rule | Trigger | Refer to | Suspected |
|---|---|---|---|
| `CH-002` | Is there cough or breathing difficulty? | PHC within 24 h | Pneumonia |
| `CH-003` | Is there diarrhoea or repeated vomiting? | PHC within 24 h | Diarrhoea / vomiting |
| `CH-006` | Is weight much less than expected for age? | ICDS / NRC if SAM | Malnutrition |
| `CH-011` † | Is there blood in the stool (dysentery)? | PHC within 24 h | Dysentery |
| `CH-012` † | Are the palms or inner eyelids very pale (anaemia)? | PHC for Hb check | Anaemia |

### Risk score
**Weights:** c1 = 3 · c2 = 2 · c3 = 2 · c4 = 3 · c5 = 3 · c6 = 2 · c7 = 3 · c8 = 3 · c9 = 3 · c10 = 3 · c11 = 2 · c12 = 2 · c13 = 4  
**Bands by score:** 🟢 GREEN 0–2 · 🟡 YELLOW 3–5 · 🔴 RED 6–100

---

## 🤰 Pregnant Mother Checkup (ANC) — `pregnancy`
*গর্ভবতী মায়ের চেকআপ*

**Who:** Pregnant woman (female)  
**Purpose:** **Antenatal (ANC)** screening. Focus on the big maternal killers: hypertensive disease (pre-eclampsia/eclampsia), antepartum haemorrhage, severe anaemia, sepsis/malaria, and reduced fetal movement.  
**🟢 In easy words:** A pregnant woman's check-up. Watches mainly for **high blood pressure** (which can lead to fits), **bleeding**, **very low blood (anaemia)**, infection, and the **baby moving less**.

### Questions (14)

| ID | Question |
|---|---|
| `p1` | Is blood pressure high? |
| `p2` | Is there swelling of legs or face? |
| `p3` | Is there bleeding or severe abdominal pain? |
| `p4` | Has the baby's movement reduced? |
| `p5` | Has ANC checkup been missed for 3+ months? |
| `p6` | Is there blurred vision? |
| `p7` | Has there been a convulsion or fit during pregnancy? |
| `p8` | Very pale, weak, or breathless on slight exertion (severe anaemia)? |
| `p9` | Fever, especially with chills/rigors? |
| `p10` | Sudden gush or continuous leaking of fluid (PROM)? |
| `p11` | Is there a headache? |
| `p11d` | Is the headache very severe, lasting >2 days, or worsening? |
| `p12` | Is there dizziness or weakness? |
| `p9r` | Fever WITH chills or rigors? |

### Hard-stop rules → 🔴 RED (8)

| Rule | Trigger (answer = yes) | Refer to | Suspected condition |
|---|---|---|---|
| `ANC-001` | Is blood pressure high? | FRU / DH immediately | Pre-eclampsia / Eclampsia |
| `ANC-003` | Is there bleeding or severe abdominal pain? | FRU / DH immediately | Antepartum haemorrhage |
| `ANC-004` | Has the baby's movement reduced? | FRU / DH same day | Reduced fetal movement |
| `ANC-006` | Is there blurred vision? | FRU / DH immediately | Imminent eclampsia |
| `ANC-007` | Has there been a convulsion or fit during pregnancy? | FRU / DH immediately | Eclampsia |
| `ANC-008` † | Very pale, weak, or breathless on slight exertion (severe anaemia)? | FRU / DH | Severe anaemia in pregnancy |
| `ANC-010` † | Sudden gush or continuous leaking of fluid (PROM)? | FRU / DH | Premature rupture of membranes |
| `ANC-009R` † | Fever WITH chills or rigors? | FRU / DH immediately by 108 | Malaria, Maternal sepsis / chorioamnionitis |

### Combination rules (6)

| Rule | If ALL of these are yes | Band | Suspected condition |
|---|---|---|---|
| `ANC-COMB-001` | p1 (Is blood pressure high?) **+** p2 (Is there swelling of legs or) | 🔴 RED | Pre-eclampsia |
| `ANC-COMB-002` | p6 (Is there blurred vision?) **+** p2 (Is there swelling of legs or) | 🔴 RED | Imminent eclampsia |
| `ANC-COMB-003` † | p3 (Is there bleeding or severe ) **+** p4 (Has the baby's movement redu) | 🔴 RED | Placental abruption, IUGR |
| `ANC-COMB-004` † | p1 (Is blood pressure high?) **+** p6 (Is there blurred vision?) | 🔴 RED | Severe pre-eclampsia |
| `ANC-COMB-005` † | p11 (Is there a headache?) **+** p11d (Is the headache very severe,) | 🔴 RED | Severe/persistent headache — pre-eclampsia |
| `ANC-COMB-006` † | p11 (Is there a headache?) **+** p2 (Is there swelling of legs or) | 🔴 RED | Pre-eclampsia |

### Numeric (vital) rules (15)

| Rule | Vital | Condition | Band | Meaning |
|---|---|---|---|---|
| `ANC-VITAL-001` | `systolic_bp` | ≥ 140 | 🔴 RED | Systolic BP ≥ 140 mmHg — pre-eclampsia. |
| `ANC-VITAL-002` | `diastolic_bp` | ≥ 90 | 🔴 RED | Diastolic BP ≥ 90 mmHg — pre-eclampsia. |
| `ANC-VITAL-003` | `haemoglobin` | < 7 | 🔴 RED | Hb < 7 g/dL — severe anaemia. |
| `ANC-VITAL-004` | `haemoglobin` | 7–10 | 🟡 YELLOW | Hb 7–10 g/dL — moderate anaemia. Increase IFA. |
| `ANC-VITAL-005` † | `systolic_bp` | ≥ 160 | 🔴 RED | Systolic BP ≥ 160 mmHg — severe hypertension. Lay on left side, call 108 and take to FRU now. |
| `ANC-VITAL-006` † | `urine_protein_plus` | ≥ 2 | 🔴 RED | Urine protein ≥ 2+ = pre-eclampsia. Refer FRU. |
| `ANC-VITAL-007` † | `fundal_height_weeks_diff` | > 4 | 🟡 YELLOW | Fundal height >4 weeks discrepancy = IUGR or polyhydramnios suspicion. |
| `ANC-VITAL-008` † | `gestational_age_weeks` | < 37 | 🔴 RED | Labour pain or leaking before 37 weeks = preterm labour. Refer FRU without cervical examination if pains/leaking present. |
| `ANC-VITAL-009` † | `labour_hours` | > 12 | 🔴 RED | Labour pain >12 h = obstructed labour risk. Refer FRU/DH immediately. |
| `ANC-VITAL-010` † | `leaking_hours_no_labour` | > 12 | 🔴 RED | Leaking >12 h without labour = PROM with chorioamnionitis risk. Refer FRU now. |
| `ANC-VITAL-011` † | `tsh_miu` | > 10 | 🔴 RED | TSH > 10 mIU/L on report = thyroid problem. Refer to PHC/MO — do not start or change any medicine yourself. |
| `ANC-VITAL-012` † | `tsh_miu` | 2.5–10 | 🟡 YELLOW | TSH 2.5–10 mIU/L on report = mildly raised thyroid. Refer to PHC/MO; do not give medicine yourself. |
| `ANC-VITAL-013` † | `ogtt_2hr_mg_dl` | ≥ 140 | 🟡 YELLOW | High sugar on report (GDM). Refer to PHC/MO for GDM management. ASHA role: counsel balanced diet and ensure follow-up. Do not give medicine or insulin yourself. |
| `ANC-VITAL-014` † | `fhr_bpm` | < 120 | 🔴 RED | FHR <120 bpm = fetal distress. Position mother left lateral, refer FRU/DH immediately. |
| `ANC-VITAL-015` † | `fhr_bpm` | > 160 | 🔴 RED | FHR >160 bpm = fetal distress (maternal fever or chorioamnionitis). Refer FRU now. |

### Yellow rules → 🟡 YELLOW (5)

| Rule | Trigger | Refer to | Suspected |
|---|---|---|---|
| `ANC-002` | Is there swelling of legs or face? | PHC within 24 h | Oedema |
| `ANC-005` | Has ANC checkup been missed for 3+ months? | PHC within 7 days | Missed ANC |
| `ANC-011` † | Is there a headache? | PHC within 24 h | Headache (assess for pre-eclampsia) |
| `ANC-012` † | Is there dizziness or weakness? | PHC within 24 h | Dizziness (anaemia / hypotension) |
| `ANC-009` † | Fever, especially with chills/rigors? | PHC within 24 h | Fever in pregnancy (rule out malaria/UTI/sepsis) |

### Risk score
**Weights:** p1 = 4 · p2 = 2 · p3 = 4 · p4 = 3 · p5 = 1 · p6 = 3 · p7 = 4 · p8 = 3 · p9 = 3 · p10 = 3 · p11 = 2 · p11d = 2 · p12 = 1 · p9r = 4  
**Bands by score:** 🟢 GREEN 0–2 · 🟡 YELLOW 3–5 · 🔴 RED 6–100

---

## 🤱 Postpartum Checkup (0–42 days) — `delivery_pnc`
*প্রসব-পরবর্তী চেকআপ (০-৪২ দিন)*

**Who:** Mother 0–42 days after delivery (female)  
**Purpose:** **Postnatal** mother care. Focus on postpartum haemorrhage (PPH), puerperal sepsis, postpartum eclampsia, breathing difficulty, and a postpartum-depression screen.  
**🟢 In easy words:** A mother in the ~6 weeks after delivery. Watches mainly for **heavy bleeding** and **infection (fever)** — the two biggest dangers after childbirth — plus her mood.

### Questions (11)

| ID | Question |
|---|---|
| `pp1` | Is there excessive bleeding or foul-smelling discharge? |
| `pp2` | Is there fever or chills? |
| `pp3` | Is there breast pain, swelling, or red marks? |
| `pp4` | Is there severe abdominal pain or suture problem? |
| `pp5` | Is there burning or difficulty urinating? |
| `pp6` | Is there extreme weakness or dizziness? |
| `pp7` | Has there been a convulsion or fit after delivery? |
| `pp8` | Is there difficulty breathing? |
| `pp9` | Persistent low mood, crying, sleep/appetite loss, or no interest in the baby? |
| `pp6s` | Fainting / collapsing, or unable to stand (severe weakness)? |
| `pp10` | Unable to control urine or stool (incontinence)? |

### Hard-stop rules → 🔴 RED (5)

| Rule | Trigger (answer = yes) | Refer to | Suspected condition |
|---|---|---|---|
| `PNC-001` † | Is there excessive bleeding or foul-smelling discharge? | FRU / DH immediately | Postpartum haemorrhage, Puerperal sepsis |
| `PNC-007` | Has there been a convulsion or fit after delivery? | FRU / DH immediately | Postpartum eclampsia |
| `PNC-008` | Is there difficulty breathing? | FRU / DH immediately | Pulmonary embolism, Cardiac failure, Severe anaemia / sepsis |
| `PNC-006S` † | Fainting / collapsing, or unable to stand (severe weakness)? | FRU / DH via 108 now | Concealed PPH, Hypovolaemic shock |
| `PNC-009` | Unable to control urine or stool (incontinence)? | FRU / DH immediately | Obstetric fistula / sphincter injury |

### Combination rules (4)

| Rule | If ALL of these are yes | Band | Suspected condition |
|---|---|---|---|
| `PNC-COMB-001` | pp1 (Is there excessive bleeding ) **+** pp2 (Is there fever or chills?) | 🔴 RED | Puerperal sepsis |
| `PNC-COMB-002` | pp4 (Is there severe abdominal pa) **+** pp2 (Is there fever or chills?) | 🔴 RED | Peritonitis |
| `PNC-COMB-003` † | pp1 (Is there excessive bleeding ) **+** pp6 (Is there extreme weakness or) | 🔴 RED | Hypovolaemic shock |
| `PNC-COMB-004` † | pp3 (Is there breast pain, swelli) **+** pp2 (Is there fever or chills?) | 🔴 RED | Breast abscess |

### Numeric (vital) rules (8)

| Rule | Vital | Condition | Band | Meaning |
|---|---|---|---|---|
| `PNC-VITAL-001` | `temperature_c` | ≥ 38 | 🔴 RED | Temp ≥ 38°C postpartum = puerperal sepsis. Refer FRU. |
| `PNC-VITAL-002` | `haemoglobin` | < 7 | 🔴 RED | Hb < 7 g/dL — refer FRU for transfusion. |
| `PNC-VITAL-003` | `haemoglobin` | 7–10 | 🟡 YELLOW | Hb 7–10 g/dL — moderate anaemia. Increase IFA. |
| `PNC-VITAL-004` † | `systolic_bp` | ≥ 140 | 🔴 RED | Postpartum systolic BP ≥ 140 = postpartum pre-eclampsia. Lay on left side, call 108 and take to FRU now. |
| `PNC-VITAL-005` † | `heart_rate` | > 110 | 🟡 YELLOW | HR > 110/min = sepsis or anaemia risk. Refer PHC for evaluation. |
| `PNC-VITAL-006` † | `pads_soaked_per_30min` | ≥ 2 | 🔴 RED | ≥2 pads soaked in 30 min = PPH. Uterine massage, call 108. |
| `PNC-VITAL-007` † | `pads_per_day` | > 5 | 🔴 RED | More than 5 pads per day (HBNC threshold) = excessive bleeding. PPH/sepsis risk — refer FRU now. |
| `PNC-VITAL-008` † | `temperature_c` | ≥ 38.9 | 🔴 RED | Temp ≥ 38.9°C postpartum = severe puerperal sepsis. Keep the mother warm and hydrated, do not give medicine yourself, call 108 and take to FRU now. |

### Yellow rules → 🟡 YELLOW (6)

| Rule | Trigger | Refer to | Suspected |
|---|---|---|---|
| `PNC-002` | Is there fever or chills? | PHC within 24 h | Puerperal fever |
| `PNC-003` | Is there breast pain, swelling, or red marks? | PHC within 24 h | Mastitis |
| `PNC-004` | Is there severe abdominal pain or suture problem? | PHC within 24 h | Wound infection |
| `PNC-005` | Is there burning or difficulty urinating? | PHC within 24 h | UTI |
| `PNC-006` | Is there extreme weakness or dizziness? | PHC for Hb check | Anaemia |
| `PNC-009` † | Persistent low mood, crying, sleep/appetite loss, or no interest in the baby? | PHC / MO counselling | Postpartum depression |

### Risk score
**Weights:** pp1 = 4 · pp2 = 2 · pp3 = 1 · pp4 = 2 · pp5 = 1 · pp6 = 2 · pp7 = 4 · pp8 = 3 · pp9 = 1 · pp6s = 4  
**Bands by score:** 🟢 GREEN 0–2 · 🟡 YELLOW 3–5 · 🔴 RED 6–100

---

## 💉 Immunization — UIP National Schedule — `immunisation`
*টিকা মিস / ইমিউনাইজেশন*

**Who:** Child 0–16 years (UIP schedule)  
**Purpose:** Checks vaccine status against the national **UIP** schedule. No emergencies — flags missed/overdue doses for catch-up, defers if the child is currently ill, and routes a prior severe reaction (AEFI) to a doctor before the next dose.  
**🟢 In easy words:** Checking a child's vaccines. **Never an emergency** — it just flags shots that are missed or late so they can be caught up, and pauses if the child is sick.

### Questions (6)

| ID | Question |
|---|---|
| `im1` | What is the child's age in months? |
| `im2` | Which vaccine was missed? |
| `im3` | How many days ago was the vaccine due? |
| `im4` | Does the child have any illness now? |
| `im5` | Has the booster dose been missed for child aged 1–5 years? |
| `im6` | Was there a severe reaction after a previous vaccine dose (AEFI)? |

### Yellow rules → 🟡 YELLOW (6)

| Rule | Trigger | Refer to | Suspected |
|---|---|---|---|
| `IMM-001` | What is the child's age in months? | Nearest immunisation session within 7 days | Missed primary vaccines |
| `IMM-002` | Which vaccine was missed? | Nearest immunisation session within 7 days | Missed vaccine |
| `IMM-003` | Has the booster dose been missed for child aged 1–5 years? | Next immunisation session | Missed booster |
| `IMM-004` | Does the child have any illness now? | Reschedule within 7 days of recovery | Illness at vaccination |
| `IMM-005` | How many days ago was the vaccine due? | PHC catch-up session | Long vaccine gap |
| `IMM-006` † | Was there a severe reaction after a previous vaccine dose (AEFI)? | Refer MO before next dose | AEFI history |

### Risk score
**Weights:** im4 = 1 · im5 = 1 · im6 = 1  
**Bands by score:** 🟢 GREEN 0–0 · 🟡 YELLOW 1–100 · 🔴 RED undefined–undefined

---

## 👶 Child Development Screening (2 months–3 years) — `development`
*শিশু বিকাশ যাচাই (২ মাস–৩ বছর)*

**Who:** Child 2 months–3 years  
**Purpose:** Early **child-development screening** using the MCP-card milestones. Flags a missed milestone for a development assessment at a DEIC / health centre.  
**🟢 In easy words:** Checking whether a small child is growing and learning on time — sitting, walking, talking. A missed milestone means **"send for a check-up,"** not an emergency.

### Questions (2)

| ID | Question |
|---|---|
| `d1` | Which age band is the child in? |
| `d2` | Is ANY ONE of the danger signs listed for this age present? (check the list below) |

### Yellow rules → 🟡 YELLOW (1)

| Rule | Trigger | Refer to | Suspected |
|---|---|---|---|
| `DEV-001` | Is ANY ONE of the danger signs listed for this age present? (check the list below) | DEIC / নিকটতম স্বাস্থ্যকেন্দ্র — বিকাশ মূল্যায়ন | Developmental delay |

### Risk score
**Weights:** d2 = 3  
**Bands by score:** 🟢 GREEN 0–0 · 🟡 YELLOW 1–100 · 🔴 RED undefined–undefined

---

## 🚨 Emergency — Global Hard-Stop Engine — `emergency`
*জরুরি অবস্থা যাচাই*

**Who:** Any patient (cross-cutting)  
**Purpose:** A universal "is this a crisis now?" sweep usable for any patient — and **re-run in the background against every other module** so a life-threatening sign is never missed. Any positive = RED, reach FRU/DH within 30 minutes.  
**🟢 In easy words:** A quick **"is this a life-threatening crisis right now?"** check for anyone — heavy bleeding, fits, can't breathe, poisoning, snakebite, shock. Any one means **rush to a hospital within 30 minutes.**

### Questions (8)

| ID | Question |
|---|---|
| `e1` | Is there excessive bleeding? |
| `e2` | Has there been convulsion or loss of consciousness? |
| `e3` | Is there severe difficulty breathing? |
| `e4` | Is the patient unresponsive or unconscious? |
| `e5` | Snakebite, venomous sting, or animal bite? |
| `e6` | Poison, pesticide, or overdose ingested? |
| `e7` | Cold clammy skin, very weak pulse, extreme listlessness (shock)? |
| `e8` | Major injury, bleeding from a large wound, or severe burn? |

### Hard-stop rules → 🔴 RED (8)

| Rule | Trigger (answer = yes) | Refer to | Suspected condition |
|---|---|---|---|
| `EM-001` | Is there excessive bleeding? | FRU / DH ≤ 30 min | Haemorrhage |
| `EM-002` | Has there been convulsion or loss of consciousness? | FRU / DH immediately | Eclampsia / Seizure |
| `EM-003` | Is there severe difficulty breathing? | FRU / DH ≤ 30 min | Respiratory failure |
| `EM-004` | Is the patient unresponsive or unconscious? | FRU / DH ≤ 30 min | Unconsciousness |
| `EM-006` † | Snakebite, venomous sting, or animal bite? | FRU / DH ≤ 30 min | Envenomation, Rabies risk |
| `EM-007` † | Poison, pesticide, or overdose ingested? | FRU / DH ≤ 30 min | Poisoning / pesticide ingestion |
| `EM-008` † | Cold clammy skin, very weak pulse, extreme listlessness (shock)? | FRU / DH ≤ 30 min | Shock / circulatory collapse |
| `EM-009` † | Major injury, bleeding from a large wound, or severe burn? | FRU / DH ≤ 30 min | Major trauma, Severe burn |

### Risk score
**Weights:** e1 = 4 · e2 = 4 · e3 = 4 · e4 = 4 · e5 = 4 · e6 = 4 · e7 = 4 · e8 = 4  
**Bands by score:** 🟢 GREEN 0–0 · 🟡 YELLOW undefined–undefined · 🔴 RED 1–100

---

## 📖 Glossary (medical words in plain language)

| Term | In easy words |
|---|---|
| **PSBI** | Possible Serious Bacterial Infection — a dangerous infection in a newborn that can turn deadly fast. |
| **IMNCI** | The standard government method for checking sick young children. |
| **ANC** | Antenatal care — pregnancy check-ups *before* birth. |
| **PNC** | Postnatal care — mother/baby check-ups *after* birth. |
| **Pre-eclampsia / Eclampsia** | Dangerous high blood pressure in pregnancy; eclampsia is when it causes fits. |
| **APH** | Antepartum haemorrhage — bleeding during late pregnancy. |
| **PPH** | Postpartum haemorrhage — heavy bleeding after delivery (the #1 killer of new mothers). |
| **PROM** | Premature rupture of membranes — the water bag breaks early. |
| **Puerperal sepsis** | A serious infection in the mother after delivery. |
| **Omphalitis** | Infection of a newborn's belly-button (umbilical) area. |
| **Kernicterus** | Brain damage from very severe newborn jaundice. |
| **Jaundice** | Yellow colour of skin/eyes. |
| **Cyanosis** | Bluish skin/lips from low oxygen. |
| **Hypothermia** | Body too cold. |
| **Fontanelle** | The soft spot on a baby's head; bulging can mean brain infection. |
| **Sepsis** | Infection that has spread through the body — life-threatening. |
| **MUAC** | Mid-Upper-Arm Circumference — a coloured tape around the upper arm to check for malnutrition. |
| **SAM / MAM** | Severe / Moderate Acute Malnutrition (very thin / thin for the child's size). |
| **Anaemia** | Low blood (low haemoglobin) — causes weakness and danger in pregnancy. |
| **SpO₂ / hypoxia** | Oxygen level in the blood; hypoxia = too little oxygen. |
| **Tachypnoea** | Breathing too fast. |
| **Tachycardia** | Heart beating too fast. |
| **Hyperpyrexia** | Very high fever (≥40°C). |
| **GDM** | Gestational diabetes — high blood sugar during pregnancy. |
| **TSH** | A thyroid blood test; abnormal values need a doctor. |
| **FHR** | Fetal heart rate — the baby's heartbeat. |
| **Fundal height** | Belly height of the womb, used to estimate the baby's growth. |
| **IUGR** | The baby growing slower/smaller than expected. |
| **Dysentery** | Diarrhoea with blood. |
| **Mastitis** | Painful, infected breast (while breastfeeding). |
| **AEFI** | A bad reaction after a vaccine. |
| **UIP** | The national vaccination schedule. |
| **ORS** | Oral Rehydration Solution — clean water + sugar **+ salt** to treat dehydration. |
| **KMC** | Kangaroo Mother Care — keeping a small baby skin-to-skin on the chest to stay warm. |
| **PHC** | Primary Health Centre — the nearest small government clinic. |
| **CHC** | Community Health Centre — a bigger clinic above the PHC. |
| **FRU** | First Referral Unit — a hospital that can do emergencies/C-sections/transfusions. |
| **SNCU** | Special Newborn Care Unit — a newborn ICU. |
| **DH** | District Hospital — the big district-level hospital. |
| **DEIC** | District Early Intervention Centre — for child-development problems. |
| **HBNC / HBYC** | Home-Based Newborn / Young-Child Care — the ASHA's scheduled home visits. |
