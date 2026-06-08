# AshaMitra — Clinical Audit Findings (engine v2.4.0-draft)

Generated from a multi-agent clinical audit: 6 modules x 3 lenses (under-triage / over-triage / realism-scope), each finding adversarially verified against IMNCI / PSBI / ANC-NHM / UIP protocols. **This is an AI plausibility review — it does NOT replace clinical sign-off by the AIIH&PH / WB Health committee.** Severities are the reviewers; the committee makes the final call.

## Status of this round

- ✅ **Applied now (16 rules, band UNCHANGED):** out-of-scope drug / injection / procedure instructions removed from the ASHA action text and replaced with in-scope first aid + 108 + refer + notify ANM/MO. See `docs/apply_scope_fixes.js`.
- ⏳ **Deferred to committee:** band changes, new danger-sign questions, and over-triage threshold tuning — these change clinical behaviour and must be a clinician decision, not an automated edit.

## CRITICAL (22)

| # | Rule | Status | Issue | Suggested fix |
|---|---|---|---|---|
| 1 | `CONTRA_NB_002 (lib/core/services/layers/contradiction_checker.dart:82-89)` | ⏳ committee | Blocking contradiction suppresses a real cyanosis RED — baby gets NO triage band | Set CONTRA_NB_002 blocking:false (warn-only, like CONTRA_NB_001), OR remove it entirely. Cyanosis (n6) must independently lock RED via NB-006 regardless of the n3 answer. Never let a contradiction check on a danger-sign question halt the pipeline. |
| 2 | `GRADED-MILD (rule_engine.dart:390-434) affecting NB-001..NB-011` | ⏳ committee | A 'mild/partial' answer on any neonatal PSBI danger sign only yields YELLOW for days 7-28 | For the newborn module, treat mild on PSBI danger-sign questions (n1,n3,n4,n5,n6,n7,n8,n9,n10) as RED, not YELLOW (these signs have no benign partial form in a neonate). Simplest: extend the ADAPT_D_001 'YELLOW→RED' escalation to the full neonatal window (age < 28 days, not < 7), and/or have the newborn module force mild→RED. n2 (fever) is already absolute. |
| 3 | `NB-COMB-005` | ✅ fixed | Action tells ASHA to inject IM gentamicin + give amoxicillin — outside ASHA scope and unsafe | Remove all drug/injection instructions from the ASHA-facing action. Replace with: action_bn 'দুধ খাচ্ছে না + জ্বর = সম্ভাব্য গুরুতর সংক্রমণ (PSBI)। শিশুকে গরম রাখুন, বুকের দুধ খাওয়ানোর চেষ্টা চালিয়ে যান, এখনই ১০৮ ডেকে SNCU/FRU-তে নিয়ে যান এবং ANM/MO-কে জানান।' Keep antibiotic guidance only in a separate MO/ANM-facing field, not the ASHA action. |
| 4 | `NB-COMB-004` | ✅ fixed | Action tells ASHA to 'give first dose amoxicillin' — prescribing/administering outside scope | Strip the amoxicillin instruction from the ASHA action. Replace with warm-the-baby + keep-feeding + call-108 + refer-SNCU/FRU-now + notify-ANM/MO wording. Move any pre-referral antibiotic note to a clinician-only field. |
| 5 | `CH-004` | ⏳ committee | "Not able to drink/feed" (c4) banded YELLOW — it is an IMNCI GENERAL DANGER SIGN = RED | Move c4 out of yellow_rules into hard_stop_rules as a RED hard-stop (mirror CH-009): band RED, referral 'FRU/DH immediately', and raise its risk_engine score from 1 to 3 to match the other general danger signs. Keep CH-004's clinical advice but at RED. |
| 6 | `MISSING: chest indrawing / stridor / grunting` | ⏳ committee | Severe-pneumonia signs (chest indrawing, stridor at rest, grunting) have NO question and NO rule | Add a question e.g. c13 'বুকের নিচের অংশ ভেতরে ঢুকে যাচ্ছে, বা বিশ্রামেও শ্বাসের শব্দ (stridor)?' and a hard_stop_rule (RED, FRU immediately, suspected 'Severe pneumonia / very severe disease'). Optionally a grunting/unable-to-feed-with-cough sign too. |
| 7 | `ANC-009` | ⏳ committee | Fever with chills/rigors in pregnancy banded only YELLOW (PHC within 24h), not RED | Split fever into graded handling: keep mild/isolated low fever as YELLOW (ANC-009), but add a RED hard_stop rule for fever WITH rigors/chills (and/or combination rules fever+reduced-fetal-movement, fever+abdominal-pain, fever+PROM/leaking → sepsis/chorioamnionitis = RED, FRU/108 immediately). Either add a dedicated 'fever with rigors' question graded as severe→RED, or raise p9 risk score and add fever-based combination_rules so the documented 'rigors = FRU now' actually fires. |
| 8 | `MISSING: no fetal movement / absent fetal movement` | ⏳ committee | Absent fetal movement collapsed into 'reduced' and banded same-day, not immediate | Add a severe-grade / second question distinguishing 'no movement at all / not felt for several hours' → RED with referral 'FRU/DH immediately by 108', keeping 'reduced but present' as same-day. Update ANC-004 action to escalate the absent-movement case to immediate transport. |
| 9 | `ANC-VITAL-011, ANC-VITAL-012` | ✅ fixed | Engine tells ASHA to start and titrate Levothyroxine — prescribing, far outside ASHA scope, and needs a lab TSH she cannot obtain | Remove drug dosing entirely. If retained at all as a YELLOW informational rule, action should be: 'TSH abnormal on report — refer to PHC/MO; do NOT start or change any medicine yourself.' Better: drop ANC-VITAL-011/012 from the ASHA-facing engine; thyroid management belongs to the MO. |
| 10 | `ANC-VITAL-013` | ✅ fixed | GDM rule instructs ASHA to start Medical Nutrition Therapy and insulin — prescribing/management outside scope, needs lab OGTT | Reframe as referral only: 'If OGTT/sugar high on report → refer PHC/MO for GDM management. ASHA role: counsel diet, ensure follow-up.' Strip the words 'insulin' and 'Start Medical Nutrition Therapy' (the latter is a clinician order). |
| 11 | `ANC-007, ANC-COMB-004, ANC-VITAL-005` | ✅ fixed | 'Prepare MgSO4' is repeatedly given as an ASHA action — magnesium sulphate is an FRU/staff-nurse drug, not in ASHA scope | Replace 'prepare MgSO4' in all three rules with ASHA-appropriate first aid + transport: 'Lay on left side, protect from injury/keep airway clear, do NOT give anything by mouth, call 108 and accompany to FRU now.' Leave MgSO4 instructions to the FRU. |
| 12 | `PNC-006` | ⏳ committee | Isolated postpartum dizziness / extreme weakness banded only YELLOW (Hb check) — misses hypovolaemic shock from concealed PPH | Add a hard_stop_rule: pp6 EQUALS true AND answer graded 'severe' (fainting / cannot stand) => RED, referral 'FRU/DH via 108 now, lay flat with legs raised'. At minimum elevate isolated pp6 to RED/urgent (same-hour) rather than YELLOW-24h, and change referral from 'PHC for Hb check' to 'FRU now' for the severe grade. |
| 13 | `PNC-001` | ✅ fixed | Tells ASHA to perform bimanual uterine compression — an SBA/MO procedure outside ASHA scope | Replace with ASHA-scope wording: 'জরায়ুর উপরে পেটে শক্ত করে মালিশ করুন (fundal massage), মাকে শুইয়ে রাখুন, এখনই ১০৮ ডেকে FRU/DH-তে নিয়ে যান।' i.e. external fundal massage only, call 108, refer FRU. Remove all reference to bimanual compression. |
| 14 | `PNC-VITAL-008` | ✅ fixed | Instructs ASHA to give first-dose antibiotic — prescribing/administering is outside ASHA scope | Drop 'first dose antibiotic'. The ASHA action for temp ≥38.9°C postpartum should be: keep warm/hydrated, do NOT give any drug, call 108, refer FRU/DH immediately. Move any 'first dose' instruction to a facility-level note, not the ASHA action text. |
| 15 | `MISSING: acute post-vaccination anaphylaxis / AEFI now` | ⏳ committee | No RED rule for an acute severe reaction occurring NOW after a dose (anaphylaxis/collapse) | Add a question (e.g. 'Did the child have swelling of face/mouth, difficulty breathing, generalised rash, collapse, convulsion or high fever right after a dose?') and a hard_stop_rule banding RED: lay flat/recovery position, call 108, immediate referral to FRU/PHC; do NOT give next dose. Also route the immunisation module's RED conditions into the global emergency hard-stop engine. |
| 16 | `IMM-006` | ⏳ committee | Prior severe AEFI banded YELLOW and the rule is draft/unsigned (may be inactive) | Promote to an active (non-draft) rule, raise to RED/urgent MO review with an explicit 'do not vaccinate until medically cleared' hold, and give it a score weight that can reach RED. Get clinical sign-off so it is not gated as draft. |
| 17 | `IMM-001` | ⏳ committee | Every infant 0-12 months is force-flagged YELLOW ("go to PHC within 24 h") on age alone | Require an actual gap before firing. Add a condition that a vaccine is missed (im2 affirmative) AND overdue beyond a tolerance (im3 != '১ সপ্তাহ'), OR remove IMM-001's standalone age trigger entirely. A missed dose ≤1 week with a well child should resolve GREEN with action 'attend next session site' — not a YELLOW PHC-24h referral. |
| 18 | `IMM-002` | ⏳ committee | Any missed vaccine = YELLOW "PHC within 24 h", even a dose due 1 week ago | Gate IMM-002 on duration: only escalate when im3 is '১ মাস' (1 month, → schedule catch-up, GREEN/home-advice band) or '৩ মাসের বেশি' (→ keep IMM-005). A 1-week gap with a well child should be GREEN with 'attend next routine session', reserving YELLOW for genuinely overdue (>1 month) catch-up that needs active follow-up rather than urgent PHC referral. |
| 19 | `MISSING: chest pain / cardiac / stroke (FAST)` | ⏳ committee | No danger sign for acute chest pain, cardiac event, or stroke in the universal hard-stop net | Add two RED hard-stop questions+rules to the emergency module: (1) e9 'Sudden severe chest pain / pain radiating to arm or jaw / cold sweat?' -> RED, suspected_conditions ['Acute coronary syndrome'], referral FRU/DH immediately, advise aspirin per protocol if available + 108; (2) e10 'Sudden face droop, arm weakness, or slurred speech (BE-FAST)?' -> RED, suspected_conditions ['Stroke'], note time of onset, 108 -> FRU/DH. Give each score 4 in risk_engine so the global cross-sweep also catches them. |
| 20 | `MISSING: choking / airway obstruction / drowning` | ⏳ committee | No danger sign for choking, foreign-body airway obstruction, or drowning | Add e11 'Choking — sudden inability to breathe/speak/cough, or near-drowning?' -> RED hard-stop with action_en giving age-appropriate first aid (back blows + chest/abdominal thrusts for choking; recovery position + 108 for drowning), referral FRU/DH immediately, score 4. |
| 21 | `MISSING: obstetric walk-in emergencies (cord prolapse / labour with danger / baby part visible)` | ⏳ committee | Universal emergency net omits acute obstetric crises that present as walk-ins | Add e12 'Pregnant: cord or any baby part visible, or wants-to-push with no progress / heavy labour bleeding?' -> RED hard-stop, action: knee-chest position, do not push cord back, do not delay, 108 -> FRU/DH immediately, suspected_conditions ['Cord prolapse','Obstructed labour'], score 4. |
| 22 | `MISSING: severe dehydration / child unable to drink / lethargic infant` | ⏳ committee | No general danger sign for severe dehydration or a lethargic young child/infant who cannot drink | Add e13 'Child/infant: too weak/lethargic to drink or breastfeed, or sunken eyes with very slow skin pinch (severe dehydration)?' -> RED hard-stop, action: start ORS by spoon if able to swallow, 108 -> FRU/SNCU, suspected_conditions ['Severe dehydration','PSBI'], score 4. |

## MAJOR (39)

| # | Rule | Issue |
|---|---|---|
| 1 | `NB-006` | ANY yellow skin hard-stops to RED/SNCU — fires on benign physiological jaundice in ~60-80% of normal newborns |
| 2 | `MISSING: severe chest indrawing` | Severe chest indrawing is not a distinct sign — conflated into 'fast or difficult' (n3) |
| 3 | `MISSING: apnea / stopped breathing / grunting` | Apnea (breathing pauses) and grunting — core young-infant signs — are entirely absent |
| 4 | `MISSING: dehydration in newborn` | No dehydration / poor urine output / sunken fontanelle-and-eyes sign for the neonate |
| 5 | `MISSING: vomiting everything / not keeping feeds down` | 'Vomits everything / cannot keep feeds down' (IMNCI general danger sign) absent from newborn |
| 6 | `NB-VITAL-006` | Heart-rate > 180/min rule needs a pulse oximeter/stethoscope the ASHA does not have |
| 7 | `NB-VITAL-001` | SpO2 < 90 rule assumes a pulse oximeter the ASHA does not carry |
| 8 | `CH-012` | Severe palmar/conjunctival pallor (c12) banded YELLOW — severe anaemia is RED-tier in IMNCI |
| 9 | `CH-VITAL-004` | Fast-breathing thresholds are not age-gated — an infant 2–12 mo with RR 40–49 can be mis-triaged |
| 10 | `CH-002` | Any cough fires YELLOW (PHC within 24 h) even with no pneumonia signs |
| 11 | `CH-003` | Any diarrhoea fires YELLOW even when there is no dehydration (should be Plan A home care) |
| 12 | `risk_engine` | Additive score (RED threshold = 6) escalates three benign 2-point symptoms to RED FRU |
| 13 | `CH-VITAL-008` | Action tells ASHA to 'prepare oxygen' — out of ASHA scope and equipment |
| 14 | `CH-VITAL-006` | WFA Z-score < -3 rule requires a calculation no ASHA can do and the vital is never captured |
| 15 | `CH-005` | Severe dehydration action says 'Start ORS' with no 'only if able to drink' caveat — aspiration risk |
| 16 | `MISSING: decreased / no urine output (oliguria)` | Reduced or no urine output is entirely absent from the ANC module |
| 17 | `MISSING: severe / persistent vomiting (hyperemesis & late-pregnancy vomiting)` | No capture of severe persistent vomiting / inability to keep fluids down |
| 18 | `ANC-VITAL-001 / ANC-VITAL-002 / ANC-VITAL-003 (all numeric_rules)` | BP / Hb / fetal-heart numeric safety nets never fire for an equipment-free ASHA |
| 19 | `ANC-001` | Subjective "Is BP high?" fires an immediate FRU/DH emergency hard-stop on isolated, possibly mild, hypertension |
| 20 | `ANC-VITAL-001` | Measured BP at the very threshold of hypertension (systolic ≥140 / diastolic ≥90) fires RED, same urgency as severe range |
| 21 | `ANC-006` | Isolated blurred vision fires an immediate FRU/DH hard-stop, but blurred vision alone is a very common benign pregnancy symptom |
| 22 | `ANC-VITAL-006, ANC-VITAL-007, ANC-VITAL-014, ANC-VITAL-015` | Numeric rules depend on assessments an equipment-free ASHA cannot make (urine protein, fundal height interpretation, fetal heart rate) |
| 23 | `ANC-001, ANC-003, ANC-007, ANC-COMB-001, ANC-COMB-003, ANC-COMB-004` | RED maternal emergencies say 'refer FRU/DH' but never tell the ASHA to call the 108 ambulance / how to transport |
| 24 | `PNC-002` | Reported postpartum fever/chills (no thermometer) banded YELLOW with 24h delay — under-triages puerperal sepsis |
| 25 | `MISSING: postpartum pre-eclampsia symptoms (severe headache / blurred vision / epigastric pain)` | No symptom question for postpartum pre-eclampsia danger signs — only caught after the fit (pp7) or if a BP cuff is present |
| 26 | `MISSING: reduced / no urine output (oliguria-anuria)` | Reduced or absent urine output is not asked — misses a shock / sepsis / AKI danger sign |
| 27 | `risk_engine.thresholds` | Risk-engine scoring can DOWNGRADE single YELLOW danger symptoms to GREEN |
| 28 | `PNC-COMB-004` | Simple mastitis (breast pain + fever) banded RED / 108-ambulance, but referral says routine PHC antibiotics |
| 29 | `PNC-VITAL-001` | Single low-grade reading of exactly 38.0 C fires RED 'sepsis', contradicting PNC-002 which calls isolated fever YELLOW |
| 30 | `PNC-007` | Action tells ASHA to 'prepare MgSO4' — magnesium sulfate is not an ASHA drug |
| 31 | `PNC-VITAL-004` | Relies on a BP reading ASHA cannot take, and again says 'prepare MgSO4' |
| 32 | `IMM-004` | A child who is ill NOW is capped at YELLOW with no IMNCI danger-sign escalation |
| 33 | `risk_engine.thresholds.RED` | Risk engine can never output RED — RED band is structurally impossible in this module |
| 34 | `IMM-003` | Missed booster routinely escalated to YELLOW "PHC within 24 h" |
| 35 | `BAND-SEMANTICS` | YELLOW band semantics ('PHC within 24 h') are wrong for an entire module about routine catch-up |
| 36 | `EM-006/EM-007/EM-008/EM-009` | Four life-threatening hard-stop rules are status:'draft' / clinical_sign_off_pending, weakening the safety net |
| 37 | `EM-001` | EM-001 tells ASHA to 'apply uterine compression' — an out-of-scope SBA maneuver; correct ASHA action is fundal massage |
| 38 | `EM-006` | Animal-bite branch bundles snakebite-grade 108/FRU≤30min/ASV urgency onto every animal bite |
| 39 | `EM-003` | Mild-graded answers on qualified emergency questions force YELLOW PHC referral for self-limiting presentations |

---
Total: **22 critical + 39 major** confirmed findings. Minor (style/equipment) omitted. Sign-off: ____________ (AIIH&PH)  ____________ (WB Health)  Date: ______
