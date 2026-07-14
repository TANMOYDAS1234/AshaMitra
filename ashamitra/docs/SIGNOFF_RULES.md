# ASHAMitra — Sign-off-pending rules

> Auto-generated from [`assets/data/asha_engine.json`](../assets/data/asha_engine.json) — engine `asha_cdss_engine_v2` **v2.6.0-guideline-aligned**.

These rules carry `clinical_sign_off_pending: true`. They are **live** — they fire and affect the band exactly like any other rule — but are flagged as **draft additions awaiting a clinician's sign-off** (newer guideline items or proxy thresholds). When one fires, the pipeline attaches a `SAFETY_A_001` advisory note to the output (see [PIPELINE.md](PIPELINE.md), Layer 9). This file is the validation worklist.

**Total: 64 sign-off-pending rules.**

## 🟢 In easy words
These rules are **already switched on and working** — when one matches, the app warns the worker exactly like every other rule. The only difference: they are **newer rules a doctor hasn't formally approved ("signed off") yet.**

Think of a new staff member who is already doing the job while their paperwork waits for a senior's signature — nothing is broken, the work still happens. This page is simply the **list a doctor should review and approve.** The **Scenario** column shows a real situation in which each rule would fire.

## 🍼 Newborn Checkup (0–28 days) — `newborn` (12)

| Rule | Type | Band | Scenario (example case — when it fires) | Action shown to worker |
|---|---|---|---|---|
| `NB-008` | hard_stop | 🔴 RED | Winter home visit to a 4-day-old: the baby feels cold to touch and isn't warming up. | PSBI hard-stop. Keep warm (skin-to-skin/kangaroo care), cover head. Refer SNCU/FRU immediately. Hypothermia is a major neonatal killer. |
| `NB-010` | hard_stop | 🔴 RED | A 10-day-old has many pus-filled blisters on the skin (or pus draining from an ear). | Many pustules/pus-filled blisters or ear pus = PSBI local bacterial infection. Refer FRU/DH immediately. |
| `NB-011` | hard_stop | 🔴 RED | The soft spot on a 2-week-old's head is bulging and tense. | Bulging fontanelle = possible meningitis. Refer SNCU/FRU immediately. |
| `NB-COMB-002` | combination | 🔴 RED | A 3-day-old looks deeply yellow AND refuses to breastfeed. | Jaundice + poor feeding = kernicterus risk. Refer SNCU immediately. |
| `NB-COMB-003` | combination | 🔴 RED | A newborn is floppy / barely moving AND is breathing hard. | Lethargy + breathing difficulty = severe sepsis. Refer SNCU immediately. |
| `NB-COMB-004` | combination | 🔴 RED | A 6-day-old has a red, pus-y belly-button AND a fever. | Umbilical infection + fever = systemic sepsis risk (PSBI). Keep the baby warm, keep breastfeeding, call 108 and take to SNCU/FRU now, and inform the ANM/MO. Do not give any medicine yourself. |
| `NB-COMB-005` | combination | 🔴 RED | A 5-day-old won't take the breast AND feels hot to touch. | Not feeding + fever = possible serious infection (PSBI). Keep the baby warm, keep trying to breastfeed, call 108 and take to SNCU/FRU now, and inform the ANM/MO. Do not give any medicine or injection yourself. |
| `NB-VITAL-005` | numeric | 🔴 RED | Thermometer reads 35.0°C on a newborn. | Temp < 35.5°C — hypothermia. Start kangaroo mother care, refer SNCU. |
| `NB-VITAL-006` | numeric | 🔴 RED | A newborn's heart rate is counted at 190/min. | HR > 180/min — severe tachycardia. Refer SNCU. |
| `NB-VITAL-007` | numeric | 🟡 YELLOW | Birth weight is 2.2 kg. | Weight 1.8–2.5 kg — LBW. KMC, breastfeed every 2 h. |
| `NB-VITAL-008` | numeric | 🔴 RED | Birth weight is 1.6 kg. | Weight < 1.8 kg — HBNC referral threshold. KMC + expressed breast milk + refer SNCU. |
| `NB-VITAL-009` | numeric | 🟡 YELLOW | A newborn's temperature is 36.0°C. | Temp 35.5–36.4°C — cold stress. KMC, warm the room, recheck in 1 hour. |

## 🧒 Child Health Check (2 months–5 years) — `child` (16)

| Rule | Type | Band | Scenario (example case — when it fires) | Action shown to worker |
|---|---|---|---|---|
| `CH-009` | hard_stop | 🔴 RED | A 2-year-old vomits up everything given and can't keep water down. | Vomiting everything = IMNCI general danger sign. Cannot keep anything down — refer FRU/DH immediately. |
| `CH-010` | hard_stop | 🔴 RED | A feverish 3-year-old has a stiff neck and cries at bright light. | Stiff neck/severe headache with fever = possible meningitis/encephalitis. Call 108, refer FRU/DH immediately. |
| `CH-004` | hard_stop | 🔴 RED | A 1-year-old refuses to eat or drink anything at all. | Complete refusal to eat/feed = IMNCI general danger sign. Call 108 and take to FRU now. |
| `CH-013` | hard_stop | 🔴 RED | A coughing 8-month-old's lower chest sucks inward with each breath. | Lower chest indrawing or stridor at rest = severe pneumonia / very severe disease. Keep the child calm, call 108 and take to FRU now. |
| `CH-COMB-002` | combination | 🔴 RED | A child has had fever for 6 days AND a cough. | Fever > 5 days + cough = possible pneumonia or malaria. Refer PHC today. |
| `CH-COMB-003` | combination | 🔴 RED | A child has diarrhoea AND is refusing to eat. | Diarrhoea + refusal to eat = severe dehydration risk. If the child can swallow, give ORS by spoon; call 108 and refer to FRU now. |
| `CH-COMB-004` | combination | 🔴 RED | A child has diarrhoea AND sunken eyes / dry lips. | Diarrhoea + dehydration signs = IMNCI Plan C. Refer FRU immediately for IV fluids, continue ORS en route. |
| `CH-VITAL-004` | numeric | 🔴 RED | A 9-month-old's breathing is counted at 55/min. | RR ≥ 50/min (2 mo–1 y) = severe pneumonia. Refer FRU. |
| `CH-VITAL-005a` | numeric | 🔴 RED | A child's temperature is 40.2°C. | Temp ≥ 40°C = hyperpyrexia. Refer FRU, test for malaria. |
| `CH-VITAL-005b` | numeric | 🟡 YELLOW | A child's temperature is 39.5°C. | Temp 39–40°C = high fever. Refer PHC, give paracetamol. |
| `CH-VITAL-006` | numeric | 🔴 RED | Weight-for-age is far below normal (z-score around −3.5). | WFA Z-score < -3 = severe underweight. Refer NRC. |
| `CH-VITAL-006b` | numeric | 🟡 YELLOW | Weight-for-age is mildly low (z-score around −2.4). | WFA Z-score -3 to -2 = moderate underweight (MAM). Refer ICDS/Anganwadi for supplementary nutrition, weigh monthly. (MCP card: yellow zone, pg 28–31) |
| `CH-VITAL-007` | numeric | 🟡 YELLOW | A 3-year-old is breathing 42/min. | RR ≥ 40/min (child 1–5 y) = possible pneumonia. Refer PHC within 24 h. Chest indrawing = RED. |
| `CH-VITAL-008` | numeric | 🟡 YELLOW | A finger-oximeter reads 92% on a child. | SpO2 90–94% = moderate hypoxia. Keep the child calm and upright, refer to PHC promptly. |
| `CH-011` | yellow | 🟡 YELLOW | A child's stool has visible blood. | Blood in stool = dysentery, needs antibiotics. Refer PHC within 24 h. With dehydration/lethargy = FRU. |
| `CH-012` | yellow | 🟡 YELLOW | A child's palms and inner eyelids look very pale. | Pallor = anaemia. Refer PHC for Hb. Severe pallor = FRU (possible transfusion). |

## 🤰 Pregnant Mother Checkup (ANC) — `pregnancy` (21)

| Rule | Type | Band | Scenario (example case — when it fires) | Action shown to worker |
|---|---|---|---|---|
| `ANC-008` | hard_stop | 🔴 RED | A pregnant woman is very pale and gets breathless climbing a few steps. | Severe anaemia is a leading maternal killer. Severe pallor/breathlessness = refer FRU/DH for Hb + transfusion planning. |
| `ANC-010` | hard_stop | 🔴 RED | At 8 months, a sudden gush of fluid leaks (waters broken early). | Sudden gush/continuous leaking = PROM, infection/preterm-labour risk. No vaginal exam, keep a clean pad, refer FRU/DH. |
| `ANC-009R` | hard_stop | 🔴 RED | A pregnant woman has a fever with shaking chills / rigors. | Fever with rigors in pregnancy = possible malaria or sepsis. Lay on left side, call 108 and take to FRU now. |
| `ANC-COMB-003` | combination | 🔴 RED | A pregnant woman is bleeding AND the baby is barely moving. | Bleeding + reduced fetal movement = placental emergency. Refer FRU immediately. |
| `ANC-COMB-004` | combination | 🔴 RED | High blood pressure AND blurred eyesight. | High BP + blurred vision = severe pre-eclampsia. Lay on left side, call 108 and take to FRU now. |
| `ANC-COMB-005` | combination | 🔴 RED | A bad headache that has lasted more than 2 days and is worsening. | Severe or persistent headache = pre-eclampsia danger sign. Refer FRU/DH immediately. |
| `ANC-COMB-006` | combination | 🔴 RED | A headache together with swelling of the face/legs. | Headache + swelling = pre-eclampsia. Refer FRU immediately. |
| `ANC-VITAL-005` | numeric | 🔴 RED | BP reads 168/100. | Systolic BP ≥ 160 mmHg — severe hypertension. Lay on left side, call 108 and take to FRU now. |
| `ANC-VITAL-006` | numeric | 🔴 RED | A urine dipstick shows 2+ protein. | Urine protein ≥ 2+ = pre-eclampsia. Refer FRU. |
| `ANC-VITAL-007` | numeric | 🟡 YELLOW | The belly measures 4+ weeks bigger/smaller than the dates suggest. | Fundal height >4 weeks discrepancy = IUGR or polyhydramnios suspicion. |
| `ANC-VITAL-008` | numeric | 🔴 RED | Labour pains start at 34 weeks (before 37). | Labour pain or leaking before 37 weeks = preterm labour. Refer FRU without cervical examination if pains/leaking present. |
| `ANC-VITAL-009` | numeric | 🔴 RED | Labour pains have continued 14 hours without delivery. | Labour pain >12 h = obstructed labour risk. Refer FRU/DH immediately. |
| `ANC-VITAL-010` | numeric | 🔴 RED | Waters broke 13 hours ago but labour hasn't started. | Leaking >12 h without labour = PROM with chorioamnionitis risk. Refer FRU now. |
| `ANC-VITAL-011` | numeric | 🔴 RED | A lab report shows TSH 12 mIU/L. | TSH > 10 mIU/L on report = thyroid problem. Refer to PHC/MO — do not start or change any medicine yourself. |
| `ANC-VITAL-012` | numeric | 🟡 YELLOW | A lab report shows TSH 6 mIU/L. | TSH 2.5–10 mIU/L on report = mildly raised thyroid. Refer to PHC/MO; do not give medicine yourself. |
| `ANC-VITAL-013` | numeric | 🟡 YELLOW | A 2-hour sugar test (OGTT) reads 150 mg/dL. | High sugar on report (GDM). Refer to PHC/MO for GDM management. ASHA role: counsel balanced diet and ensure follow-up. Do not give medicine or insulin yourself. |
| `ANC-VITAL-014` | numeric | 🔴 RED | The baby's heartbeat is counted at 110/min. | FHR <120 bpm = fetal distress. Position mother left lateral, refer FRU/DH immediately. |
| `ANC-VITAL-015` | numeric | 🔴 RED | The baby's heartbeat is counted at 170/min. | FHR >160 bpm = fetal distress (maternal fever or chorioamnionitis). Refer FRU now. |
| `ANC-011` | yellow | 🟡 YELLOW | A mild headache with no other danger sign. | Headache — refer PHC within 24 h to check BP. If severe/persistent, or with swelling/blurred vision = FRU now. |
| `ANC-012` | yellow | 🟡 YELLOW | A pregnant woman reports feeling dizzy and weak. | Dizziness/weakness — refer PHC for Hb + BP check (anaemia or low BP). |
| `ANC-009` | yellow | 🟡 YELLOW | A fever without chills/rigors in pregnancy. | Fever in pregnancy — refer PHC within 24 h (check malaria/UTI/infection). With rigors, very high fever, or any other danger sign = FRU/DH now. |

## 🤱 Postpartum Checkup (0–42 days) — `delivery_pnc` (10)

| Rule | Type | Band | Scenario (example case — when it fires) | Action shown to worker |
|---|---|---|---|---|
| `PNC-001` | hard_stop | 🔴 RED | A mother 2 days after delivery is bleeding heavily / soaking pads fast. | PPH hard-stop. Do firm external fundal massage over the uterus, lay the mother down, call 108 and take to FRU/DH now. |
| `PNC-006S` | hard_stop | 🔴 RED | A new mother faints or cannot stand up. | Severe postpartum dizziness/collapse = possible concealed bleeding or shock. Lay flat with legs raised, call 108 and take to FRU now. |
| `PNC-COMB-003` | combination | 🔴 RED | Postpartum bleeding AND severe weakness/dizziness. | Bleeding + weakness = hypovolaemic shock. Lay head down, refer FRU immediately. |
| `PNC-COMB-004` | combination | 🔴 RED | A painful, red, swollen breast AND fever. | Breast pain + fever = breast abscess or mastitis. Refer PHC for antibiotics. |
| `PNC-VITAL-004` | numeric | 🔴 RED | BP reads 145/95 after delivery. | Postpartum systolic BP ≥ 140 = postpartum pre-eclampsia. Lay on left side, call 108 and take to FRU now. |
| `PNC-VITAL-005` | numeric | 🟡 YELLOW | A new mother's pulse is 118/min. | HR > 110/min = sepsis or anaemia risk. Refer PHC for evaluation. |
| `PNC-VITAL-006` | numeric | 🔴 RED | 2 or more pads are fully soaked within 30 minutes. | ≥2 pads soaked in 30 min = PPH. Uterine massage, call 108. |
| `PNC-VITAL-007` | numeric | 🔴 RED | More than 5 pads are soaked in a single day. | More than 5 pads per day (HBNC threshold) = excessive bleeding. PPH/sepsis risk — refer FRU now. |
| `PNC-VITAL-008` | numeric | 🔴 RED | Temperature is 39.0°C after delivery. | Temp ≥ 38.9°C postpartum = severe puerperal sepsis. Keep the mother warm and hydrated, do not give medicine yourself, call 108 and take to FRU now. |
| `PNC-009` | yellow | 🟡 YELLOW | A new mother is persistently sad, not interested in the baby, not sleeping. | Postpartum depression screen. Counsel, involve family, refer PHC/MO. Any thought of self-harm or harming the baby = urgent referral. |

## 💉 Immunization — UIP National Schedule — `immunisation` (1)

| Rule | Type | Band | Scenario (example case — when it fires) | Action shown to worker |
|---|---|---|---|---|
| `IMM-006` | yellow | 🟡 YELLOW | Parents report the child had a severe reaction after the previous injection. | Severe reaction after a previous dose (AEFI). Refer to MO before the next dose — do not auto-schedule. |

## 🚨 Emergency — Global Hard-Stop Engine — `emergency` (4)

| Rule | Type | Band | Scenario (example case — when it fires) | Action shown to worker |
|---|---|---|---|---|
| `EM-006` | hard_stop | 🔴 RED | A person is brought in after a snakebite (or animal bite). | Hard-stop. Immobilise the limb (splint), keep below heart level, remove tight items. Do NOT cut/suck/tourniquet. Call 108, FRU/DH ≤30 min (anti-snake-venom). Animal bite: wound wash 15 min + ARV/RIG. |
| `EM-007` | hard_stop | 🔴 RED | Someone has swallowed pesticide / poison / an overdose. | Hard-stop. Do NOT induce vomiting. Bring the container/label. Protect airway, left-lateral if drowsy. Call 108, FRU/DH ≤30 min. |
| `EM-008` | hard_stop | 🔴 RED | A patient has cold clammy skin and a very weak pulse (shock). | Hard-stop. Lay flat, keep warm, raise legs, nothing by mouth. Call 108, FRU/DH ≤30 min. |
| `EM-009` | hard_stop | 🔴 RED | A road-accident victim with heavy bleeding from a large wound, or a severe burn. | Hard-stop. Direct pressure on bleeding; for burns cool with clean water, cover, apply nothing. Immobilise fractures. Call 108, FRU/DH ≤30 min. |

> ⚠️ Note: `PNC-001` (the postpartum-haemorrhage hard-stop) is a core life-threatening RED rule still flagged draft — worth formally signing off rather than leaving as draft.
