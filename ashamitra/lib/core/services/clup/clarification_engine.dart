// ─────────────────────────────────────────────────────────────────────────────
// CLUP Layer 3 — Clarification Engine
//
// Generates safe, protocol-driven follow-up questions when:
//   - Intent is non_clinical → polite redirect
//   - Intent is clinical_vague → narrow the symptom
//   - Intent is third_party → redirect to current patient
//   - Intent is unclear → open clinical prompt
//   - Relevance filter says clarification needed
//
// GOLDEN RULE:
//   Never assume GREEN when clinical information is insufficient.
//   Always ask before concluding no symptoms.
// ─────────────────────────────────────────────────────────────────────────────

import 'intent_detector.dart';

class ClarificationOutput {
  final String questionBn;       // Bengali question to speak/display
  final String questionEn;       // English (for logs)
  final ClarificationType type;
  final bool blockRuleEngine;    // true = do not run rule engine yet

  const ClarificationOutput({
    required this.questionBn,
    required this.questionEn,
    required this.type,
    required this.blockRuleEngine,
  });

  Map<String, dynamic> toMap() => {
    'question_bn': questionBn,
    'question_en': questionEn,
    'type': type.name,
    'block_rule_engine': blockRuleEngine,
  };
}

enum ClarificationType {
  nonClinicalRedirect,   // "salary বেড়েছে" → ask about health
  thirdPartyRedirect,    // "স্বামীর জ্বর" → ask about self
  vagueSymptomNarrow,    // "শরীর খারাপ" → ask what specifically
  historicalClarify,     // "আগে জ্বর ছিল" → ask if current
  moduleSpecificPrompt,  // module-aware follow-up
  insufficientInfo,      // no clinical info at all
  questionBackAnswer,    // ASHA asked us a question — brief educational answer + redirect
}

class ClarificationEngine {
  // ── Non-clinical redirects ────────────────────────────────────────────────
  static const _nonClinicalResponses = [
    (
      bn: 'আপনার কি কোনো শারীরিক সমস্যা বা অসুবিধা হচ্ছে?',
      en: 'Are you experiencing any physical problem or discomfort?',
    ),
    (
      bn: 'আপনার শরীরে কি কোনো কষ্ট বা ব্যথা আছে?',
      en: 'Do you have any pain or discomfort in your body?',
    ),
    (
      bn: 'আপনার স্বাস্থ্য সম্পর্কে কিছু বলুন — কোনো সমস্যা হচ্ছে?',
      en: 'Tell me about your health — are you having any problems?',
    ),
  ];

  // ── Third-party redirects ─────────────────────────────────────────────────
  static const _thirdPartyResponses = [
    (
      bn: 'আপনার নিজের কোনো শারীরিক সমস্যা হচ্ছে?',
      en: 'Are you yourself experiencing any physical problem?',
    ),
    (
      bn: 'আপনার শরীরে কি কোনো অসুবিধা আছে?',
      en: 'Do you have any discomfort in your own body?',
    ),
  ];

  // ── Vague symptom narrowing — per module ─────────────────────────────────
  static const _vagueNarrowByModule = <String, List<({String bn, String en})>>{
    'pregnancy': [
      (bn: 'মাথা ব্যথা, পা ফোলা, বা রক্তপাত হচ্ছে?', en: 'Headache, leg swelling, or bleeding?'),
      (bn: 'বাচ্চার নড়াচড়া কি স্বাভাবিক আছে?', en: 'Is the baby moving normally?'),
      (bn: 'চোখে ঝাপসা বা মাথা ঘুরছে?', en: 'Blurred vision or dizziness?'),
    ],
    'newborn': [
      (bn: 'শিশু কি বুকের দুধ খাচ্ছে?', en: 'Is the baby breastfeeding?'),
      (bn: 'শিশুর জ্বর বা শ্বাসকষ্ট আছে?', en: 'Does the baby have fever or breathing difficulty?'),
      (bn: 'শিশু কি নড়াচড়া করছে স্বাভাবিকভাবে?', en: 'Is the baby moving normally?'),
    ],
    'child': [
      (bn: 'জ্বর, কাশি, বা ডায়রিয়া হচ্ছে?', en: 'Fever, cough, or diarrhoea?'),
      (bn: 'শিশু কি খাচ্ছে?', en: 'Is the child eating?'),
      (bn: 'শিশুর চোখ কি গর্তে বসে গেছে?', en: 'Are the child\'s eyes sunken?'),
    ],
    'delivery_pnc': [
      (bn: 'অতিরিক্ত রক্তপাত বা দুর্গন্ধযুক্ত স্রাব হচ্ছে?', en: 'Excessive bleeding or foul discharge?'),
      (bn: 'জ্বর বা পেটে ব্যথা হচ্ছে?', en: 'Fever or abdominal pain?'),
      (bn: 'খুব দুর্বল বা মাথা ঘুরছে?', en: 'Extreme weakness or dizziness?'),
    ],
    'immunisation': [
      (bn: 'কোন টিকা মিস হয়েছে?', en: 'Which vaccine was missed?'),
      (bn: 'শিশুর বয়স কত মাস?', en: 'What is the child\'s age in months?'),
    ],
    'emergency': [
      (bn: 'খিঁচুনি, অজ্ঞান, বা শ্বাস বন্ধ হয়েছে?', en: 'Seizure, unconsciousness, or stopped breathing?'),
      (bn: 'রক্তপাত থামছে না?', en: 'Is bleeding not stopping?'),
    ],
  };

  // ── Historical clarification ──────────────────────────────────────────────
  static const _historicalClarify = (
    bn: 'এটা কি এখনও হচ্ছে, নাকি আগে হয়েছিল?',
    en: 'Is this happening now, or did it happen before?',
  );

  // ── Insufficient info ─────────────────────────────────────────────────────
  static const _insufficientInfo = (
    bn: 'আপনার কোনো শারীরিক সমস্যা হচ্ছে? বিস্তারিত বলুন।',
    en: 'Are you having any physical problem? Please describe.',
  );

  // ── Educational answer bank — common ASHA questions ───────────────────────
  // Each entry is (matcher → answer). When the question-back input contains
  // any keyword in the matcher list, we speak the short educational answer
  // and then re-ask the current clinical question. The bank covers the most
  // common questions ASHA workers ask during triage; for everything else we
  // fall back to a polite "good question, let's finish the checkup first".
  //
  // Each answer is intentionally 1-2 sentences — long enough to be useful,
  // short enough to not derail the triage flow.
  static const _educationalBank = <({List<String> keywords, String bn, String en})>[
    (
      keywords: ['ors', 'pani', 'water', 'পানিশূন্যতা', 'ডায়রিয়া'],
      bn: 'ORS বানাতে — ১ লিটার বিশুদ্ধ পানিতে ১ প্যাকেট ORS গুলিয়ে নিন। প্রতিবার পাতলা পায়খানার পর আধা কাপ খাওয়ান। এখন বলুন তো —',
      en: 'To make ORS: mix 1 packet in 1 litre clean water, give half a cup after each loose stool. Now tell me —',
    ),
    (
      keywords: ['জ্বর কমা', 'fever down', 'paracetamol', 'প্যারাসিটামল', 'bukhar kaise', 'jor kome'],
      bn: 'জ্বর কমাতে — কপালে ভেজা কাপড় দিন, প্যারাসিটামল ওজন অনুযায়ী দিন (১০-১৫ mg/kg)। ১০৪°F বা ৫ দিনের বেশি জ্বর হলে PHC-তে নিন। এখন বলুন —',
      en: 'To reduce fever: sponge with damp cloth, paracetamol 10-15 mg/kg. >104°F or >5 days → PHC. Now tell me —',
    ),
    (
      keywords: ['জন্ডিস', 'jaundice', 'হলুদ', 'piliya', 'peela'],
      bn: 'নবজাতকের জন্ডিস বেশিরভাগ স্বাভাবিক, কিন্তু ২৪ ঘণ্টার মধ্যে দেখা দিলে বা চোখ-গা হলুদ হলে SNCU-তে দেখান। বুকের দুধ বাড়িয়ে দিন। এখন বলুন —',
      en: 'Newborn jaundice is usually normal, but if it appears in 24 h or eyes/skin yellow → SNCU. Increase breastfeeding. Now tell me —',
    ),
    (
      keywords: ['anc', 'চেকআপ', 'কতবার', 'কখন যাব', 'when checkup'],
      bn: 'গর্ভাবস্থায় কমপক্ষে ৪টি ANC ভিজিট দরকার — ৩, ৬, ৮ ও ৯ মাসে। প্রতি ভিজিটে রক্তচাপ, ওজন ও Hb দেখাবেন। এখন বলুন —',
      en: 'Pregnancy needs at least 4 ANC visits — months 3, 6, 8, 9. Check BP, weight, Hb each visit. Now tell me —',
    ),
    (
      keywords: ['টিকা', 'vaccine', 'immunization', 'bcg', 'opv', 'dpt', 'pentavalent'],
      bn: 'জন্মের পরপর BCG, OPV-0, Hep-B। ৬, ১০, ১৪ সপ্তাহে Pentavalent + OPV + Rotavirus। ৯ মাসে MR। ১৬-২৪ মাসে বুস্টার। এখন বলুন —',
      en: 'At birth: BCG, OPV-0, Hep-B. 6/10/14 weeks: Penta + OPV + Rota. 9 mo: MR. 16-24 mo: boosters. Now tell me —',
    ),
    (
      keywords: ['বিপি', 'bp', 'blood pressure', 'রক্তচাপ'],
      bn: 'গর্ভাবস্থায় BP ১৪০/৯০ বা বেশি = প্রি-এক্লাম্পসিয়ার ঝুঁকি, এখনই FRU-তে নিন। ১৬০/১০০ এর বেশি = MgSO4 প্রস্তুত করুন। এখন বলুন —',
      en: 'BP ≥140/90 in pregnancy = pre-eclampsia risk, refer FRU. ≥160/100 = prepare MgSO4. Now tell me —',
    ),
    (
      keywords: ['psbi', 'নবজাতক বিপদ', 'newborn danger', 'sncu কখন'],
      bn: 'নবজাতকের ৭টি বিপদচিহ্ন: দুধ না খাওয়া, জ্বর/ঠান্ডা, দ্রুত শ্বাস, খিঁচুনি, নিস্তেজতা, নাভিতে পুঁজ, নীল/হলুদ ত্বক — যে কোনোটি = SNCU। এখন বলুন —',
      en: 'Newborn danger signs (any one → SNCU): no feeding, fever/hypothermia, fast breathing, convulsions, lethargy, navel pus, blue/yellow skin. Now tell me —',
    ),
    // ── IMNCI extractions ──────────────────────────────────────────────
    (
      keywords: ['fast breathing', 'দ্রুত শ্বাস', 'respiratory rate', 'শ্বাসের হার'],
      bn: 'IMNCI দ্রুত শ্বাসের সীমা — নবজাতক ও ২ মাস পর্যন্ত: ≥৬০/মিনিট, ২–১২ মাস: ≥৫০/মিনিট, ১–৫ বছর: ≥৪০/মিনিট। বুকে ইনড্রয়িং = গুরুতর নিউমোনিয়া, এখনই FRU। এখন বলুন —',
      en: 'IMNCI fast breathing thresholds — <2 m: ≥60/min, 2–12 m: ≥50/min, 1–5 y: ≥40/min. Chest indrawing = severe pneumonia → FRU. Now tell me —',
    ),
    (
      keywords: ['plan a', 'plan b', 'plan c', 'dehydration plan', 'imnci dehydration'],
      bn: 'IMNCI ডায়রিয়া পরিকল্পনা: Plan A (নো ডিহাইড্রেশন) — বাড়িতে ORS + জিঙ্ক ১৪ দিন। Plan B (সাম ডিহাইড্রেশন) — ৪ ঘণ্টায় ৭৫ ml/kg ORS। Plan C (সিভিয়ার) — IV তরলের জন্য FRU। এখন বলুন —',
      en: 'IMNCI diarrhoea plans: A (no dehyd) — home ORS + 14-day zinc. B (some dehyd) — 75 ml/kg ORS over 4 h. C (severe) — refer FRU for IV. Now tell me —',
    ),
    (
      keywords: ['zinc', 'জিঙ্ক', 'zinc dose'],
      bn: 'জিঙ্ক ডায়রিয়াতে: ২–৬ মাস = ১০ mg/দিন, ৬ মাস+ = ২০ mg/দিন, ১৪ দিন। বমি করলেও জিঙ্ক চালিয়ে যান। এখন বলুন —',
      en: 'Zinc for diarrhoea: 2–6 m = 10 mg/d, >6 m = 20 mg/d, for 14 days. Continue even if vomits. Now tell me —',
    ),
    (
      keywords: ['stiff neck', 'meningitis', 'মেনিনজাইটিস', 'ঘাড় শক্ত'],
      bn: 'জ্বর + ঘাড় শক্ত = মেনিনজাইটিসের সন্দেহ = VERY SEVERE FEBRILE DISEASE। প্রথম ডোজ amoxicillin + IM gentamicin দিয়ে এখনই FRU/DH-তে রেফার করুন। এখন বলুন —',
      en: 'Fever + stiff neck = meningitis suspicion = VERY SEVERE FEBRILE DISEASE. First dose amoxicillin + IM gentamicin, refer FRU/DH now. Now tell me —',
    ),
    (
      keywords: ['danger sign', 'বিপদচিহ্ন', 'general danger sign', 'imnci danger'],
      bn: 'IMNCI সাধারণ বিপদচিহ্ন (যেকোনো একটি → URGENT): দুধ/খাবার নিতে পারছে না, সব বমি করছে, নিস্তেজ/অজ্ঞান, খিঁচুনি। প্রি-রেফারাল চিকিৎসা দিয়ে এখনই হাসপাতাল। এখন বলুন —',
      en: 'IMNCI general danger signs (any one → URGENT): cannot drink/feed, vomits everything, lethargic/unconscious, convulsions. Pre-referral treatment + refer now. Now tell me —',
    ),
    (
      keywords: ['palmar pallor', 'pallor', 'palm pale', 'হাতের তালু ফ্যাকাশে'],
      bn: 'IMNCI অ্যানিমিয়া: হাতের তালু খুব ফ্যাকাশে (SEVERE PALLOR) = SEVERE ANEMIA, এখনই হাসপাতাল। হালকা ফ্যাকাশে (SOME PALLOR) = IFA সিরাপ ১৪ দিন, ১৪ দিন পর ফলো-আপ। এখন বলুন —',
      en: 'IMNCI anaemia: very pale palms = SEVERE ANEMIA, refer hospital now. Some pallor = IFA syrup 14 days, follow-up in 14 days. Now tell me —',
    ),
    (
      keywords: ['kmc', 'kangaroo', 'কাঙ্গারু', 'kangaroo mother care'],
      bn: 'কাঙ্গারু মাদার কেয়ার: শিশুকে মায়ের ত্বকের সাথে ত্বক লাগিয়ে বুকে রাখুন, কাপড় দিয়ে আবৃত করুন। দিনে ২০ ঘণ্টা পর্যন্ত। ওজন < ২.৫ কেজি বা কোল্ড স্ট্রেসে দরকার। এখন বলুন —',
      en: 'KMC: skin-to-skin on mother\'s chest, wrap together, up to 20 h/day. Needed for <2.5 kg or cold stress. Now tell me —',
    ),
    (
      keywords: ['preterm', 'প্রিটার্ম', '৩৭ সপ্তাহ', 'preterm labour'],
      bn: '৩৭ সপ্তাহের আগে প্রসব ব্যথা বা পানি ভাঙা = প্রিটার্ম লেবার। জরায়ুমুখ পরীক্ষা করবেন না, দ্রুত FRU/DH-তে রেফার করুন। পথে মা শান্ত রাখুন। এখন বলুন —',
      en: 'Labour pain or leaking before 37 weeks = preterm. Do NOT do cervical exam, refer FRU/DH urgently. Keep mother calm en route. Now tell me —',
    ),
    (
      keywords: ['mgso4', 'magnesium', 'ম্যাগনেসিয়াম', 'eclampsia treatment'],
      bn: 'গুরুতর প্রি-এক্লাম্পসিয়া/এক্লাম্পসিয়াতে — MgSO4 প্রথম লোডিং ডোজ ৪ g IV slow + ১০ g IM (৫ g প্রতি নিতম্বে), তারপর প্রতি ৪ ঘণ্টায় ৫ g IM। FRU-তে রেফার করুন। এখন বলুন —',
      en: 'Severe pre-eclampsia/eclampsia — MgSO4 loading: 4 g IV slow + 10 g IM (5 g each buttock), then 5 g IM q4h. Refer FRU. Now tell me —',
    ),
    (
      keywords: ['immunization schedule', 'টিকার সূচি', 'vaccine schedule', 'nis'],
      bn: 'জাতীয় টিকা সূচি: জন্মে BCG + OPV-0 + Hep-B। ৬/১০/১৪ সপ্তাহে OPV + Pentavalent + RVV + fIPV (৬,১৪)। ৯ মাসে MR-1 + ভিটামিন A। ১৬–২৪ মাসে MR-2 + DPT booster + OPV booster। ৫ বছরে DPT-2। ১০ ও ১৬ বছরে Td। এখন বলুন —',
      en: 'NIS: Birth BCG+OPV-0+HepB. 6/10/14 wk OPV+Penta+RVV+fIPV. 9 mo MR-1+Vit A. 16–24 mo MR-2+DPT booster. 5 y DPT-2. 10 & 16 y Td. Now tell me —',
    ),
    (
      keywords: ['td', 'tetanus pregnancy', 'টিটেনাস', 'টিডি'],
      bn: 'গর্ভাবস্থায় টিটেনাস — Td-1 প্রথম ভিজিটে, Td-2 ৪ সপ্তাহ পর। যদি ৩ বছরের মধ্যে দুটি ডোজ পেয়ে থাকেন = Td বুস্টার ১ ডোজ। 0.5 ml IM উপরের বাহুতে। এখন বলুন —',
      en: 'Pregnancy tetanus — Td-1 first visit, Td-2 +4 wk. If 2 doses within last 3 years = Td booster x1. 0.5 ml IM upper arm. Now tell me —',
    ),
    (
      keywords: ['ifa', 'iron folic', 'আয়রন', 'আইএফএ'],
      bn: 'গর্ভাবস্থায় IFA: ১০০ mg আয়রন + ৫০০ mcg ফলিক অ্যাসিড প্রতিদিন, ১০০ ট্যাবলেট মোট (৬ মাস)। Hb < ১১ = থেরাপিউটিক ২ ট্যাবলেট/দিন। এখন বলুন —',
      en: 'Pregnancy IFA: 100 mg iron + 500 mcg folate daily, 100 tablets total (6 mo). Hb <11 = therapeutic 2 tabs/day. Now tell me —',
    ),
    (
      keywords: ['pph management', 'pph treatment', 'পিপিএইচ চিকিৎসা'],
      bn: 'PPH ব্যবস্থাপনা: জরায়ু মালিশ করুন (uterine massage), Oxytocin ১০ IU IM, IV ফ্লুইড দ্রুত, মূত্রথলি খালি করুন, পা উঁচু করুন, ১০৮ কল করুন, FRU-তে রেফার। এখন বলুন —',
      en: 'PPH: uterine massage, Oxytocin 10 IU IM, rapid IV fluids, empty bladder, elevate legs, call 108, refer FRU. Now tell me —',
    ),
    (
      keywords: ['exclusive breastfeeding', 'একচেটিয়া দুধ', 'breastfeeding only', 'কেবল মায়ের দুধ'],
      bn: 'শূন্য থেকে ৬ মাস = কেবল মায়ের দুধ, এমনকি পানিও নয়। জন্মের ১ ঘণ্টার মধ্যে শুরু। চাহিদা অনুযায়ী দিন-রাত খাওয়ান। কোলোস্ট্রাম (প্রথম হলুদ দুধ) অবশ্যই দেবেন। এখন বলুন —',
      en: '0–6 mo = exclusive breastfeeding only, no water. Start within 1 h of birth. Feed on demand day+night. Give colostrum (yellow first milk). Now tell me —',
    ),
    // ── Maternal screening & supplementation (2nd extraction batch) ────
    (
      keywords: ['calcium', 'ক্যালসিয়াম', 'calcium dose', 'calcium supplement'],
      bn: 'ক্যালসিয়াম: প্রতিদিন ১ গ্রাম (৫০০ mg + ৫০০ mg ট্যাবলেট, খাবারের সাথে দুইবার)। ১৪ সপ্তাহ থেকে শুরু, প্রসবের পর ৬ মাস পর্যন্ত। IFA-র সাথে নেবেন না, ২ ঘণ্টা ব্যবধান। মোট ৭২০ ট্যাবলেট। এখন বলুন —',
      en: 'Calcium: 1 g/day (500 mg twice with meals). Start at 14 weeks, continue till 6 mo postpartum. Don\'t take with IFA — 2 h gap. Total 720 tablets. Now tell me —',
    ),
    (
      keywords: ['albendazole', 'অ্যালবেনডাজল', 'deworming', 'কৃমিনাশক'],
      bn: 'কৃমিনাশক: Albendazole ৪০০ mg একক ডোজ, ২য় ট্রাইমেস্টারে (১ম ট্রাইমেস্টারে নয়)। DOT — স্বাস্থ্যকর্মীর সামনে গিলে নিন। সামান্য বমি/পেট ব্যথা হতে পারে। এখন বলুন —',
      en: 'Deworming: Albendazole 400 mg single dose, 2nd trimester (NOT 1st). DOT — swallowed in front of health worker. May cause mild nausea. Now tell me —',
    ),
    (
      keywords: ['gdm', 'gestational diabetes', 'ogtt', 'গর্ভকালীন ডায়াবেটিস', 'glucose'],
      bn: 'GDM স্ক্রিনিং: ৭৫g OGTT ২৪-২৮ সপ্তাহে। ২-ঘণ্টা PG ≥ ১৪০ mg/dL = GDM। প্রথমে Medical Nutrition Therapy, প্রয়োজনে ইনসুলিন। প্রসবের ৬-১২ সপ্তাহ পর পুনরায় OGTT। এখন বলুন —',
      en: 'GDM screening: 75g OGTT at 24–28 weeks. 2-h PG ≥140 mg/dL = GDM. Start with MNT, insulin if needed. Repeat OGTT at 6–12 weeks postpartum. Now tell me —',
    ),
    (
      keywords: ['tsh', 'thyroid', 'levothyroxine', 'হাইপোথাইরয়েড', 'থাইরয়েড'],
      bn: 'গর্ভকালীন থাইরয়েড স্ক্রিনিং: TSH < ২.৫ (১ম) বা < ৩ (২য়/৩য় ত্রৈমাসিক) = স্বাভাবিক। ২.৫-১০ = Levothyroxine ২৫ μg/দিন। > ১০ = ৫০ μg/দিন। ৬ সপ্তাহ পর TSH পুনরায়। এখন বলুন —',
      en: 'Pregnancy thyroid screening: TSH <2.5 (T1) or <3 (T2/T3) = normal. 2.5–10 = Levothyroxine 25 μg/day. >10 = 50 μg/day. Recheck TSH in 6 weeks. Now tell me —',
    ),
    (
      keywords: ['partograph', 'পার্টোগ্রাফ', 'alert line', 'action line'],
      bn: 'পার্টোগ্রাফ: সক্রিয় প্রসবে শুরু করুন। প্রতি ৪ ঘণ্টায় জরায়ুমুখ মাপুন। অ্যালার্ট লাইন পার = এখনই FRU-তে রেফার করুন (অ্যাকশন লাইনের জন্য অপেক্ষা করবেন না)। ভ্রূণ হৃদস্পন্দন < ১২০ বা > ১৬০ = ডিসট্রেস। এখন বলুন —',
      en: 'Partograph: start in active labour. Cervix check every 4h. Cross Alert line = refer FRU NOW (don\'t wait for Action line). FHR <120 or >160 = distress. Now tell me —',
    ),
    (
      keywords: ['pnc visit', 'pnc schedule', 'pnc কখন', 'postnatal visit', 'hbnc schedule'],
      bn: 'HBNC ভিজিট সূচি — প্রাতিষ্ঠানিক প্রসব: ৩য়, ৭ম, ১৪তম, ২১শে, ২৮শে, ৪২তম দিন (৬ ভিজিট)। বাড়িতে প্রসব: ১ম, ৩য়, ৭ম, ১৪তম, ২১শে, ২৮শে, ৪২তম দিন (৭ ভিজিট)। এখন বলুন —',
      en: 'HBNC visit schedule — institutional delivery: days 3, 7, 14, 21, 28, 42 (6 visits). Home delivery: days 1, 3, 7, 14, 21, 28, 42 (7 visits). Now tell me —',
    ),
    (
      keywords: ['hbyc visit', 'hbyc schedule', 'young child visit', 'শিশু ভিজিট সূচি'],
      bn: 'HBYC ভিজিট সূচি (১৫ মাস পর্যন্ত): ৩, ৬, ৯, ১২, ১৫ মাস (৫ ভিজিট)। প্রতি ভিজিটে ওজন + ECD। ৬ মাসে complementary feeding + IFA সিরাপ। ৯ মাসে measles + Vit A। এখন বলুন —',
      en: 'HBYC schedule (up to 15 mo): months 3, 6, 9, 12, 15 (5 visits). Each visit: weight + ECD. 6 mo: CF + IFA syrup. 9 mo: measles + Vit A. Now tell me —',
    ),
    (
      keywords: ['complementary feeding', 'cf', 'কমপ্লিমেন্টারি', 'after 6 months', '৬ মাসের পর'],
      bn: '৬ মাসের পর সম্পূরক খাবার: ২-৩ চা চামচ ২-৩ বার/দিন। ৯ মাস: আধা কাপ ২-৩ বার + ১-২ নাস্তা। ১২ মাস: ৩/৪–১ কাপ ৩-৪ বার + ২ নাস্তা। বুকের দুধ চালিয়ে যান ২ বছর পর্যন্ত। এখন বলুন —',
      en: 'After 6 mo CF: 2-3 tsp 2-3x/d. 9 mo: ½ cup 2-3x + 1-2 snacks. 12 mo: ¾-1 cup 3-4x + 2 snacks. Continue breastfeeding till 2 y. Now tell me —',
    ),
    (
      keywords: ['vitamin a', 'ভিটামিন এ', 'vit a dose'],
      bn: 'ভিটামিন A: ৯ মাসে MR-1 সাথে ১ ml (১ লাখ IU)। ১৬-১৮ মাস থেকে ২য়-৯ম ডোজ প্রতি ৬ মাসে ২ ml (২ লাখ IU), ৫ বছর পর্যন্ত। ICDS-এর সাথে সমন্বয়। এখন বলুন —',
      en: 'Vit A: with MR-1 at 9 mo = 1 ml (1 lakh IU). From 16-18 mo, 2nd-9th doses every 6 mo = 2 ml (2 lakh IU), till 5 y. Coordinate with ICDS. Now tell me —',
    ),
    (
      keywords: ['anc test', 'anc check', 'যেসব পরীক্ষা', 'pregnancy test'],
      bn: 'প্রতিটি ANC ভিজিটে: ওজন, BP, Hb, প্রস্রাব (অ্যালবুমিন + সুগার), পেট পরীক্ষা, ফেটাল হার্ট। ১ম ভিজিটে: রক্তের গ্রুপ, সিফিলিস, HIV। ANC ৪ ভিজিট ন্যূনতম: ৩, ৬, ৮, ৯ মাসে। এখন বলুন —',
      en: 'Every ANC: weight, BP, Hb, urine (albumin+sugar), abdomen, FHR. 1st visit: blood group, syphilis, HIV. Minimum 4 ANC: 3, 6, 8, 9 months. Now tell me —',
    ),
    (
      keywords: ['paracetamol', 'প্যারাসিটামল dose'],
      bn: 'প্যারাসিটামল ডোজিং: শিশু ১০-১৫ mg/kg প্রতি ৪-৬ ঘণ্টায়, সর্বোচ্চ ৪ ডোজ/দিন। প্রাপ্তবয়স্ক ৫০০ mg প্রতি ৬ ঘণ্টায়। ১০৪°F পেরোলে বা শিশু ছোট হলে PHC-তে। এখন বলুন —',
      en: 'Paracetamol: child 10-15 mg/kg q4-6h, max 4 doses/day. Adult 500 mg q6h. >104°F or very young = PHC. Now tell me —',
    ),
    (
      keywords: ['amoxicillin', 'অ্যামক্সিসিলিন', 'amox dose'],
      bn: 'Amoxicillin ডোজ: শিশু ৪০-৫০ mg/kg/দিন তিন ডোজে, ৫ দিন। নবজাতকে PSBI-তে প্রথম ডোজ ৫০ mg/kg মুখে + IM gentamicin ৫ mg/kg, তারপর রেফার। এখন বলুন —',
      en: 'Amoxicillin: child 40-50 mg/kg/day in 3 doses, 5 days. Newborn PSBI: first dose 50 mg/kg oral + IM gentamicin 5 mg/kg, then refer. Now tell me —',
    ),
  ];

  /// Generic fallback when the question doesn't match any educational entry.
  static const _genericQuestionRedirect = (
    bn: 'ভালো প্রশ্ন দিদি। চেকআপ শেষ হলে এই বিষয়ে কথা বলবো। এখন বলুন —',
    en: 'Good question. We can discuss after the checkup. Now tell me —',
  );

  int _nonClinicalIndex = 0;
  int _thirdPartyIndex  = 0;
  final Map<String, int> _vagueIndexByModule = {};

  /// Generates the appropriate clarification question.
  ///
  /// [intent]    — from IntentDetector
  /// [moduleId]  — active clinical module
  /// [isHistorical] — from RelevanceFilter
  /// [rawInput]  — original ASHA utterance, used to look up educational
  ///               answers when the intent is a question-back.
  /// [preferredAnswer] — if non-null, this engine-grounded answer is used
  ///   for question-back intent instead of the static keyword bank. Allows
  ///   the pipeline to feed in answers synthesised from live engine rules
  ///   (see `EngineGroundedQA`).
  ClarificationOutput generate({
    required IntentResult intent,
    required String moduleId,
    bool isHistorical = false,
    String? rawInput,
    ({String bn, String en})? preferredAnswer,
  }) {
    // ── Question-back: ASHA asked us something — answer briefly, redirect ──
    // Resolved BEFORE historical/non-clinical because question intent wins
    // over the surface tokens in the sentence.
    if (intent.intent == IntentClass.questionBack) {
      final answer = preferredAnswer ?? _educationalAnswerFor(rawInput ?? '');
      final moduleQuestion = _moduleNudge(moduleId);
      return ClarificationOutput(
        questionBn: '${answer.bn} $moduleQuestion',
        questionEn: '${answer.en} ${_moduleNudgeEn(moduleId)}',
        type: ClarificationType.questionBackAnswer,
        blockRuleEngine: true,
      );
    }

    // ── Historical clarification ──────────────────────────────────────────
    if (isHistorical) {
      return ClarificationOutput(
        questionBn: _historicalClarify.bn,
        questionEn: _historicalClarify.en,
        type: ClarificationType.historicalClarify,
        blockRuleEngine: true,
      );
    }

    // ── Non-clinical redirect ─────────────────────────────────────────────
    if (intent.intent == IntentClass.nonClinical) {
      final r = _nonClinicalResponses[
          _nonClinicalIndex % _nonClinicalResponses.length];
      _nonClinicalIndex++;
      return ClarificationOutput(
        questionBn: r.bn,
        questionEn: r.en,
        type: ClarificationType.nonClinicalRedirect,
        blockRuleEngine: true,
      );
    }

    // ── Third-party redirect ──────────────────────────────────────────────
    if (intent.intent == IntentClass.thirdParty) {
      final r = _thirdPartyResponses[
          _thirdPartyIndex % _thirdPartyResponses.length];
      _thirdPartyIndex++;
      return ClarificationOutput(
        questionBn: r.bn,
        questionEn: r.en,
        type: ClarificationType.thirdPartyRedirect,
        blockRuleEngine: true,
      );
    }

    // ── Vague symptom — module-specific narrowing ─────────────────────────
    if (intent.intent == IntentClass.clinicalVague) {
      final moduleQuestions = _vagueNarrowByModule[moduleId] ??
          _vagueNarrowByModule['emergency']!;
      final idx = (_vagueIndexByModule[moduleId] ?? 0) % moduleQuestions.length;
      _vagueIndexByModule[moduleId] = idx + 1;
      final q = moduleQuestions[idx];
      return ClarificationOutput(
        questionBn: q.bn,
        questionEn: q.en,
        type: ClarificationType.vagueSymptomNarrow,
        blockRuleEngine: true,
      );
    }

    // ── Unclear ───────────────────────────────────────────────────────────
    return ClarificationOutput(
      questionBn: _insufficientInfo.bn,
      questionEn: _insufficientInfo.en,
      type: ClarificationType.insufficientInfo,
      blockRuleEngine: true,
    );
  }

  /// Resets rotation counters for a new session.
  void reset() {
    _nonClinicalIndex = 0;
    _thirdPartyIndex  = 0;
    _vagueIndexByModule.clear();
  }

  // ── Helpers for question-back handling ──────────────────────────────────

  /// Picks the best educational answer for [rawInput]. The bank's matchers
  /// are scored by keyword overlap; the highest-scoring entry wins. If
  /// nothing scores above zero we fall back to the generic redirect.
  ({String bn, String en}) _educationalAnswerFor(String rawInput) {
    final lower = rawInput.toLowerCase();
    int bestScore = 0;
    ({List<String> keywords, String bn, String en})? best;
    for (final entry in _educationalBank) {
      int score = 0;
      for (final kw in entry.keywords) {
        if (lower.contains(kw.toLowerCase())) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    return best != null
        ? (bn: best.bn, en: best.en)
        : (bn: _genericQuestionRedirect.bn, en: _genericQuestionRedirect.en);
  }

  /// Appended to the educational answer to nudge the ASHA back to the
  /// active clinical module's primary question.
  String _moduleNudge(String moduleId) => switch (moduleId) {
        'pregnancy'    => 'গর্ভবতী মায়ের কি কোনো অসুবিধা হচ্ছে?',
        'newborn'      => 'শিশুর কোনো সমস্যা হচ্ছে কি?',
        'child'        => 'শিশুর শরীরের অবস্থা কেমন?',
        'delivery_pnc' => 'প্রসবের পর কেমন আছেন?',
        'immunisation' => 'শিশুর কোন টিকা বাকি আছে?',
        'emergency'    => 'এখন রোগী কেমন আছেন?',
        _              => 'রোগীর অবস্থা কেমন?',
      };

  String _moduleNudgeEn(String moduleId) => switch (moduleId) {
        'pregnancy'    => 'Any concern with the pregnancy?',
        'newborn'      => 'Any problem with the baby?',
        'child'        => 'How is the child doing?',
        'delivery_pnc' => 'How is the mother postpartum?',
        'immunisation' => 'Which vaccine is pending?',
        'emergency'    => 'How is the patient now?',
        _              => 'How is the patient?',
      };
}
