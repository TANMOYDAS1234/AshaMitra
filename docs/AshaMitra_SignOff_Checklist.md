# AshaMitra - Clinical Sign-off Checklist

Engine 2.4.0-draft. Every rule below is DRAFT (clinical_sign_off_pending) - live in the app but NOT clinically validated. For each, the committee marks Approve / Adjust / Reject and confirms: clinically correct, correct band, correct referral, within ASHA scope, plain Bengali wording.

## Newborn (0-28 d)  (12 draft)

| Rule | Band | Fires when | Action / referral | Approve | Adjust | Reject | Note |
|---|---|---|---|:--:|:--:|:--:|---|
| `NB-008` (RED hard-stop) | RED | "Is the baby cold to touch / colder than normal (hypothermia)?" = Yes | PSBI hard-stop. Keep warm (skin-to-skin/kangaroo care), cover head. Refer SNCU/FRU immediately. Hypothermia is a major neonatal killer. -> SNCU / FRU immediately | [ ] | [ ] | [ ] |  |
| `NB-010` (RED hard-stop) | RED | "Many skin pustules / pus-filled blisters, or pus draining from ear?" = Yes | Many pustules/pus-filled blisters or ear pus = PSBI local bacterial infection. Refer FRU/DH immediately. -> FRU / DH immediately | [ ] | [ ] | [ ] |  |
| `NB-011` (RED hard-stop) | RED | "Is the soft spot on the head (fontanelle) bulging?" = Yes | Bulging fontanelle = possible meningitis. Refer SNCU/FRU immediately. -> SNCU / FRU immediately | [ ] | [ ] | [ ] |  |
| `NB-COMB-002` (combination) | RED | "Does the skin look yellow or bluish?" = Yes AND "Is the baby unable to breastfeed?" = Yes | Jaundice + poor feeding = kernicterus risk. Refer SNCU immediately. | [ ] | [ ] | [ ] |  |
| `NB-COMB-003` (combination) | RED | "Is the baby lethargic or not moving?" = Yes AND "Is breathing fast or difficult?" = Yes | Lethargy + breathing difficulty = severe sepsis. Refer SNCU immediately. | [ ] | [ ] | [ ] |  |
| `NB-COMB-004` (combination) | RED | "Is the navel red, swollen, or has pus?" = Yes AND "Does the baby have fever?" = Yes | Umbilical infection + fever = systemic sepsis risk. Give first dose amoxicillin, refer SNCU. | [ ] | [ ] | [ ] |  |
| `NB-COMB-005` (combination) | RED | "Is the baby unable to breastfeed?" = Yes AND "Does the baby have fever?" = Yes | Not feeding + fever = PSBI confirmed. First dose amoxicillin + IM gentamicin, refer SNCU. | [ ] | [ ] | [ ] |  |
| `NB-VITAL-005` (measurement) | RED | temperature_c < 35.5 | Temp < 35.5°C — hypothermia. Start kangaroo mother care, refer SNCU. | [ ] | [ ] | [ ] |  |
| `NB-VITAL-006` (measurement) | RED | heart_rate > 180 | HR > 180/min — severe tachycardia. Refer SNCU. | [ ] | [ ] | [ ] |  |
| `NB-VITAL-007` (measurement) | YELLOW | weight_kg between [1.8-2.5] | Weight 1.8–2.5 kg — LBW. KMC, breastfeed every 2 h. | [ ] | [ ] | [ ] |  |
| `NB-VITAL-008` (measurement) | RED | weight_kg < 1.8 | Weight < 1.8 kg — HBNC referral threshold. KMC + expressed breast milk + refer SNCU. | [ ] | [ ] | [ ] |  |
| `NB-VITAL-009` (measurement) | YELLOW | temperature_c between [35.5-36.4] | Temp 35.5–36.4°C — cold stress. KMC, warm the room, recheck in 1 hour. | [ ] | [ ] | [ ] |  |

## Child (1-5 y)  (13 draft)

| Rule | Band | Fires when | Action / referral | Approve | Adjust | Reject | Note |
|---|---|---|---|:--:|:--:|:--:|---|
| `CH-009` (RED hard-stop) | RED | "Does the child vomit everything?" = Yes | Vomiting everything = IMNCI general danger sign. Cannot keep anything down — refer FRU/DH immediately. -> FRU / DH immediately | [ ] | [ ] | [ ] |  |
| `CH-010` (RED hard-stop) | RED | "Stiff neck, light sensitivity, or severe headache with fever?" = Yes | Stiff neck/severe headache with fever = possible meningitis/encephalitis. Call 108, refer FRU/DH immediately. -> FRU / DH immediately | [ ] | [ ] | [ ] |  |
| `CH-COMB-002` (combination) | RED | "Has fever lasted more than 5 days?" = Yes AND "Is there cough or breathing difficulty?" = Yes | Fever > 5 days + cough = possible pneumonia or malaria. Refer PHC today. | [ ] | [ ] | [ ] |  |
| `CH-COMB-003` (combination) | RED | "Is there diarrhoea or repeated vomiting?" = Yes AND "Is the child completely refusing to eat?" = Yes | Diarrhoea + refusal to eat = severe dehydration risk. Start ORS, refer FRU. | [ ] | [ ] | [ ] |  |
| `CH-COMB-004` (combination) | RED | "Is there diarrhoea or repeated vomiting?" = Yes AND "Signs of dehydration — sunken eyes, dry lips?" = Yes | Diarrhoea + dehydration signs = IMNCI Plan C. Refer FRU immediately for IV fluids, continue ORS en route. | [ ] | [ ] | [ ] |  |
| `CH-VITAL-004` (measurement) | RED | respiratory_rate >= 50 | RR ≥ 50/min (2 mo–1 y) = severe pneumonia. Refer FRU. | [ ] | [ ] | [ ] |  |
| `CH-VITAL-005a` (measurement) | RED | temperature_c >= 40 | Temp ≥ 40°C = hyperpyrexia. Refer FRU, test for malaria. | [ ] | [ ] | [ ] |  |
| `CH-VITAL-005b` (measurement) | YELLOW | temperature_c between [39-40] | Temp 39–40°C = high fever. Refer PHC, give paracetamol. | [ ] | [ ] | [ ] |  |
| `CH-VITAL-006` (measurement) | RED | weight_for_age_z < -3 | WFA Z-score < -3 = severe underweight. Refer NRC. | [ ] | [ ] | [ ] |  |
| `CH-VITAL-007` (measurement) | YELLOW | respiratory_rate >= 40 | RR ≥ 40/min (child 1–5 y) = possible pneumonia. Refer PHC within 24 h. Chest indrawing = RED. | [ ] | [ ] | [ ] |  |
| `CH-VITAL-008` (measurement) | YELLOW | spo2 between [90-94] | SpO2 90–94% = moderate hypoxia. Refer PHC, prepare oxygen. | [ ] | [ ] | [ ] |  |
| `CH-011` (YELLOW) | YELLOW | "Is there blood in the stool (dysentery)?" = Yes | Blood in stool = dysentery, needs antibiotics. Refer PHC within 24 h. With dehydration/lethargy = FRU. -> PHC within 24 h | [ ] | [ ] | [ ] |  |
| `CH-012` (YELLOW) | YELLOW | "Are the palms or inner eyelids very pale (anaemia)?" = Yes | Pallor = anaemia. Refer PHC for Hb. Severe pallor = FRU (possible transfusion). -> PHC for Hb check | [ ] | [ ] | [ ] |  |

## Pregnancy (ANC)  (20 draft)

| Rule | Band | Fires when | Action / referral | Approve | Adjust | Reject | Note |
|---|---|---|---|:--:|:--:|:--:|---|
| `ANC-008` (RED hard-stop) | RED | "Very pale, weak, or breathless on slight exertion (severe anaemia)?" = Yes | Severe anaemia is a leading maternal killer. Severe pallor/breathlessness = refer FRU/DH for Hb + transfusion planning. -> FRU / DH | [ ] | [ ] | [ ] |  |
| `ANC-010` (RED hard-stop) | RED | "Sudden gush or continuous leaking of fluid (PROM)?" = Yes | Sudden gush/continuous leaking = PROM, infection/preterm-labour risk. No vaginal exam, keep a clean pad, refer FRU/DH. -> FRU / DH | [ ] | [ ] | [ ] |  |
| `ANC-COMB-003` (combination) | RED | "Is there bleeding or severe abdominal pain?" = Yes AND "Has the baby's movement reduced?" = Yes | Bleeding + reduced fetal movement = placental emergency. Refer FRU immediately. | [ ] | [ ] | [ ] |  |
| `ANC-COMB-004` (combination) | RED | "Is blood pressure high?" = Yes AND "Is there blurred vision?" = Yes | High BP + blurred vision = severe pre-eclampsia. Prepare MgSO4, refer FRU. | [ ] | [ ] | [ ] |  |
| `ANC-COMB-005` (combination) | RED | "Is there a headache?" = Yes AND "Is the headache very severe, lasting >2 days, or worsening?" = Yes | Severe or persistent headache = pre-eclampsia danger sign. Refer FRU/DH immediately. | [ ] | [ ] | [ ] |  |
| `ANC-COMB-006` (combination) | RED | "Is there a headache?" = Yes AND "Is there swelling of legs or face?" = Yes | Headache + swelling = pre-eclampsia. Refer FRU immediately. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-005` (measurement) | RED | systolic_bp >= 160 | Systolic BP ≥ 160 mmHg — severe hypertension. Prepare MgSO4, refer FRU. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-006` (measurement) | RED | urine_protein_plus >= 2 | Urine protein ≥ 2+ = pre-eclampsia. Refer FRU. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-007` (measurement) | YELLOW | fundal_height_weeks_diff > 4 | Fundal height >4 weeks discrepancy = IUGR or polyhydramnios suspicion. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-008` (measurement) | RED | gestational_age_weeks < 37 | Labour pain or leaking before 37 weeks = preterm labour. Refer FRU without cervical examination if pains/leaking present. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-009` (measurement) | RED | labour_hours > 12 | Labour pain >12 h = obstructed labour risk. Refer FRU/DH immediately. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-010` (measurement) | RED | leaking_hours_no_labour > 12 | Leaking >12 h without labour = PROM with chorioamnionitis risk. Refer FRU now. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-011` (measurement) | RED | tsh_miu > 10 | TSH >10 mIU/L = overt hypothyroidism. Start Levothyroxine 50 μg/day now, repeat TSH after 6 weeks. Critical for fetal brain development. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-012` (measurement) | YELLOW | tsh_miu between [2.5-10] | TSH 2.5–10 mIU/L = subclinical hypothyroidism. Start Levothyroxine 25 μg/day, repeat TSH in 6 weeks. Target <2.5 (T1) or <3 (T2/T3). | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-013` (measurement) | YELLOW | ogtt_2hr_mg_dl >= 140 | 75g OGTT 2-h PG ≥140 mg/dL = GDM (WHO/India criteria). Start Medical Nutrition Therapy, insulin if needed. Screen at 24–28 weeks. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-014` (measurement) | RED | fhr_bpm < 120 | FHR <120 bpm = fetal distress. Position mother left lateral, refer FRU/DH immediately. | [ ] | [ ] | [ ] |  |
| `ANC-VITAL-015` (measurement) | RED | fhr_bpm > 160 | FHR >160 bpm = fetal distress (maternal fever or chorioamnionitis). Refer FRU now. | [ ] | [ ] | [ ] |  |
| `ANC-011` (YELLOW) | YELLOW | "Is there a headache?" = Yes | Headache — refer PHC within 24 h to check BP. If severe/persistent, or with swelling/blurred vision = FRU now. -> PHC within 24 h | [ ] | [ ] | [ ] |  |
| `ANC-012` (YELLOW) | YELLOW | "Is there dizziness or weakness?" = Yes | Dizziness/weakness — refer PHC for Hb + BP check (anaemia or low BP). -> PHC within 24 h | [ ] | [ ] | [ ] |  |
| `ANC-009` (YELLOW) | YELLOW | "Fever, especially with chills/rigors?" = Yes | Fever in pregnancy — refer PHC within 24 h (check malaria/UTI/infection). With rigors, very high fever, or any other danger sign = FRU/DH now. -> PHC within 24 h | [ ] | [ ] | [ ] |  |

## Postpartum  (9 draft)

| Rule | Band | Fires when | Action / referral | Approve | Adjust | Reject | Note |
|---|---|---|---|:--:|:--:|:--:|---|
| `PNC-001` (RED hard-stop) | RED | "Is there excessive bleeding or foul-smelling discharge?" = Yes | PPH hard-stop. Refer FRU/DH immediately. Bimanual uterine compression if trained. -> FRU / DH immediately | [ ] | [ ] | [ ] |  |
| `PNC-COMB-003` (combination) | RED | "Is there excessive bleeding or foul-smelling discharge?" = Yes AND "Is there extreme weakness or dizziness?" = Yes | Bleeding + weakness = hypovolaemic shock. Lay head down, refer FRU immediately. | [ ] | [ ] | [ ] |  |
| `PNC-COMB-004` (combination) | RED | "Is there breast pain, swelling, or red marks?" = Yes AND "Is there fever or chills?" = Yes | Breast pain + fever = breast abscess or mastitis. Refer PHC for antibiotics. | [ ] | [ ] | [ ] |  |
| `PNC-VITAL-004` (measurement) | RED | systolic_bp >= 140 | Postpartum systolic BP ≥ 140 = postpartum pre-eclampsia. Prepare MgSO4. | [ ] | [ ] | [ ] |  |
| `PNC-VITAL-005` (measurement) | YELLOW | heart_rate > 110 | HR > 110/min = sepsis or anaemia risk. Refer PHC for evaluation. | [ ] | [ ] | [ ] |  |
| `PNC-VITAL-006` (measurement) | RED | pads_soaked_per_30min >= 2 | ≥2 pads soaked in 30 min = PPH. Uterine massage, call 108. | [ ] | [ ] | [ ] |  |
| `PNC-VITAL-007` (measurement) | RED | pads_per_day > 5 | More than 5 pads per day (HBNC threshold) = excessive bleeding. PPH/sepsis risk — refer FRU now. | [ ] | [ ] | [ ] |  |
| `PNC-VITAL-008` (measurement) | RED | temperature_c >= 38.9 | Temp ≥ 38.9°C / 102°F postpartum = severe puerperal sepsis. First dose antibiotic, refer FRU now. | [ ] | [ ] | [ ] |  |
| `PNC-009` (YELLOW) | YELLOW | "Persistent low mood, crying, sleep/appetite loss, or no interest in the baby?" = Yes | Postpartum depression screen. Counsel, involve family, refer PHC/MO. Any thought of self-harm or harming the baby = urgent referral. -> PHC / MO counselling | [ ] | [ ] | [ ] |  |

## Immunization  (1 draft)

| Rule | Band | Fires when | Action / referral | Approve | Adjust | Reject | Note |
|---|---|---|---|:--:|:--:|:--:|---|
| `IMM-006` (YELLOW) | YELLOW | "Was there a severe reaction after a previous vaccine dose (AEFI)?" = Yes | Severe reaction after a previous dose (AEFI). Refer to MO before the next dose — do not auto-schedule. -> Refer MO before next dose | [ ] | [ ] | [ ] |  |

## Emergency  (4 draft)

| Rule | Band | Fires when | Action / referral | Approve | Adjust | Reject | Note |
|---|---|---|---|:--:|:--:|:--:|---|
| `EM-006` (RED hard-stop) | RED | "Snakebite, venomous sting, or animal bite?" = Yes | Hard-stop. Immobilise the limb (splint), keep below heart level, remove tight items. Do NOT cut/suck/tourniquet. Call 108, FRU/DH ≤30 min (anti-snake-venom). Animal bite: wound wash 15 min + ARV/RIG. -> FRU / DH ≤ 30 min | [ ] | [ ] | [ ] |  |
| `EM-007` (RED hard-stop) | RED | "Poison, pesticide, or overdose ingested?" = Yes | Hard-stop. Do NOT induce vomiting. Bring the container/label. Protect airway, left-lateral if drowsy. Call 108, FRU/DH ≤30 min. -> FRU / DH ≤ 30 min | [ ] | [ ] | [ ] |  |
| `EM-008` (RED hard-stop) | RED | "Cold clammy skin, very weak pulse, extreme listlessness (shock)?" = Yes | Hard-stop. Lay flat, keep warm, raise legs, nothing by mouth. Call 108, FRU/DH ≤30 min. -> FRU / DH ≤ 30 min | [ ] | [ ] | [ ] |  |
| `EM-009` (RED hard-stop) | RED | "Major injury, bleeding from a large wound, or severe burn?" = Yes | Hard-stop. Direct pressure on bleeding; for burns cool with clean water, cover, apply nothing. Immobilise fractures. Call 108, FRU/DH ≤30 min. -> FRU / DH ≤ 30 min | [ ] | [ ] | [ ] |  |

---

Total draft rules awaiting sign-off: 59.

Sign-off: ____________ (AIIH&PH)   ____________ (WB Health Secretariat)   Date: ________
