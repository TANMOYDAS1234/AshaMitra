// Draft refinement (safe variant): de-conflate the ANC danger-sign questions so
// an ISOLATED mild/short symptom no longer auto-fires RED, while every truly
// dangerous path still hits RED. BP and blurred-vision stay RED (no downgrade).
//
//   p1  "BP high?"            → RED  (unchanged band, reworded to BP-only)
//   p6  "blurred vision?"     → RED  (unchanged band, reworded to vision-only)
//   p11 "headache?"           → YELLOW (isolated headache → PHC for BP check)   [NEW]
//   p11d "headache severe / >2 days / worsening?"                               [NEW]
//        + p11  → RED   (severity/DURATION step: severe or persistent → emergency)
//   p11 + p2 (swelling) → RED  (pre-eclampsia)                                  [NEW]
//   p12 "dizziness/weakness?" → YELLOW (anaemia/low-BP → PHC)                    [NEW]
//
// All new rules tagged clinical_sign_off_pending. Run:
//   node docs/apply_split_duration.js

const fs = require('fs');
const path = require('path');
const FILE = path.join(__dirname, '..', 'ashamitra', 'assets', 'data', 'asha_engine.json');
const eng = JSON.parse(fs.readFileSync(FILE, 'utf8'));
const preg = eng.modules.find((m) => m.module_id === 'pregnancy');
if (!preg) throw new Error('pregnancy module missing');

const q = (id) => preg.questions.find((x) => x.id === id);
const haveQ = (id) => preg.questions.some((x) => x.id === id);
const haveRule = (id) => ['hard_stop_rules', 'combination_rules', 'yellow_rules', 'numeric_rules']
  .some((k) => (preg[k] || []).some((r) => r.ruleId === id));
const addScore = (id, score) => {
  if (!preg.risk_engine.score_rules.some((s) => s.condition === id))
    preg.risk_engine.score_rules.push({ condition: id, score });
};
const draft = (o) => ({ clinical_sign_off_pending: true, status: 'draft', source: 'v3_draft_split', ...o });

// 1) Re-scope the two conflated questions (band unchanged → still RED).
if (q('p1')) { q('p1').text_bn = 'রক্তচাপ বেশি?'; q('p1').text_en = 'Is blood pressure high?'; }
if (q('p6')) { q('p6').text_bn = 'চোখে ঝাপসা দেখছেন?'; q('p6').text_en = 'Is there blurred vision?'; }

// 2) New questions.
const NEWQ = [
  { id: 'p11',  text_bn: 'মাথা ব্যথা হচ্ছে?', text_en: 'Is there a headache?', options: ['হ্যাঁ', 'না'] },
  { id: 'p11d', text_bn: 'মাথা ব্যথা কি খুব তীব্র, ২ দিনের বেশি, বা বাড়ছে?', text_en: 'Is the headache very severe, lasting >2 days, or worsening?', options: ['হ্যাঁ', 'না'] },
  { id: 'p12',  text_bn: 'মাথা ঘোরা বা দুর্বল লাগছে?', text_en: 'Is there dizziness or weakness?', options: ['হ্যাঁ', 'না'] },
];
for (const nq of NEWQ) if (!haveQ(nq.id)) preg.questions.push(nq);

// 3) New YELLOW rules (isolated mild symptom → PHC, not emergency).
preg.yellow_rules = preg.yellow_rules || [];
let yp = preg.yellow_rules.length;
if (!haveRule('ANC-011')) preg.yellow_rules.push(draft({
  ruleId: 'ANC-011', priority: ++yp, band: 'YELLOW', referral: 'PHC within 24 h',
  condition_set: [{ question_id: 'p11', operator: 'EQUALS', value: true }],
  action_bn: 'মাথা ব্যথা — রক্তচাপ মাপতে ২৪ ঘণ্টার মধ্যে PHC-তে যান। তীব্র/ক্রমাগত হলে, বা ফোলা/ঝাপসা দৃষ্টির সাথে = এখনই FRU।',
  action_en: 'Headache — refer PHC within 24 h to check BP. If severe/persistent, or with swelling/blurred vision = FRU now.',
  suspected_conditions: ['Headache (assess for pre-eclampsia)'], danger_signs: ['Headache'],
}));
if (!haveRule('ANC-012')) preg.yellow_rules.push(draft({
  ruleId: 'ANC-012', priority: ++yp, band: 'YELLOW', referral: 'PHC within 24 h',
  condition_set: [{ question_id: 'p12', operator: 'EQUALS', value: true }],
  action_bn: 'মাথা ঘোরা/দুর্বলতা — রক্তাল্পতা বা নিম্ন রক্তচাপের জন্য PHC-তে Hb ও BP পরীক্ষা করান।',
  action_en: 'Dizziness/weakness — refer PHC for Hb + BP check (anaemia or low BP).',
  suspected_conditions: ['Dizziness (anaemia / hypotension)'], danger_signs: ['Dizziness'],
}));

// 4) New RED combinations (severity/duration + context) — never downgraded.
preg.combination_rules = preg.combination_rules || [];
if (!haveRule('ANC-COMB-005')) preg.combination_rules.push(draft({
  ruleId: 'ANC-COMB-005', band: 'RED',
  condition_set: [
    { question_id: 'p11',  operator: 'EQUALS', value: true },
    { question_id: 'p11d', operator: 'EQUALS', value: true },
  ],
  action_bn: 'তীব্র বা ক্রমাগত মাথা ব্যথা = প্রি-এক্লাম্পসিয়ার বিপদচিহ্ন। এখনই FRU/DH-তে রেফার করুন।',
  action_en: 'Severe or persistent headache = pre-eclampsia danger sign. Refer FRU/DH immediately.',
  suspected_conditions: ['Severe/persistent headache — pre-eclampsia'], danger_signs: ['Severe headache'],
}));
if (!haveRule('ANC-COMB-006')) preg.combination_rules.push(draft({
  ruleId: 'ANC-COMB-006', band: 'RED',
  condition_set: [
    { question_id: 'p11', operator: 'EQUALS', value: true },
    { question_id: 'p2',  operator: 'EQUALS', value: true },
  ],
  action_bn: 'মাথা ব্যথা + ফোলা = প্রি-এক্লাম্পসিয়া। এখনই FRU-তে রেফার করুন।',
  action_en: 'Headache + swelling = pre-eclampsia. Refer FRU immediately.',
  suspected_conditions: ['Pre-eclampsia'], danger_signs: ['Headache', 'Oedema'],
}));

addScore('p11', 2); addScore('p11d', 2); addScore('p12', 1);

eng.version = '2.3.0-draft';
eng.split_duration = {
  note: 'ANC headache/dizziness de-conflated from BP/vision; isolated mild symptom = YELLOW, severe/persistent/combined = RED. Draft, sign-off pending.',
};

fs.writeFileSync(FILE, JSON.stringify(eng, null, 2) + '\n', 'utf8');
console.log(`pregnancy module refined -> engine ${eng.version}`);
console.log('questions:', preg.questions.map((x) => x.id).join(', '));
