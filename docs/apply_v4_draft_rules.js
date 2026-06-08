// Clinical-audit remediation round 2 — the 4 CONFIRMED-CRITICAL under-triage /
// missing-danger-sign findings, staged as DRAFT (clinical_sign_off_pending:true,
// status:'draft') for the AIIH&PH / WB Health committee. Bands here DO change
// triage behaviour (all escalations toward RED — the safe direction), so every
// rule is flagged pending and must be clinically signed off before relying on it.
//   node docs/apply_v4_draft_rules.js
//
//  1. CH-004  "child completely refusing to eat" (c4)  YELLOW → RED hard-stop
//             (IMNCI general danger sign "not able to drink/feed"); score 1→3.
//  2. ANC-009R fever WITH chills/rigors in pregnancy (new q p9r) → RED
//             (malaria / maternal sepsis).
//  3. PNC-006S severe postpartum dizziness / fainting (new q pp6s) → RED
//             (concealed PPH / hypovolaemic shock).
//  4. CH-013  lower chest indrawing / stridor at rest (new q c13) → RED
//             (severe pneumonia / very severe disease).

var fs = require('fs');
var path = require('path');
var FILE = path.join(__dirname, '..', 'ashamitra', 'assets', 'data', 'asha_engine.json');
var eng = JSON.parse(fs.readFileSync(FILE, 'utf8'));

function mod(id) { return eng.modules.find(function (m) { return m.module_id === id; }); }
function q(m, id) { return (m.questions || []).find(function (x) { return x.id === id; }); }
function addQuestion(m, obj) { if (!q(m, obj.id)) (m.questions = m.questions || []).push(obj); }
function addRule(m, arr, rule) {
  m[arr] = m[arr] || [];
  if (!m[arr].some(function (r) { return r.ruleId === rule.ruleId; })) m[arr].push(rule);
}
function setScore(m, cond, score) {
  var re = (m.risk_engine = m.risk_engine || {});
  re.score_rules = re.score_rules || [];
  var hit = re.score_rules.find(function (s) { return s.condition === cond; });
  if (hit) hit.score = score; else re.score_rules.push({ condition: cond, score: score });
}

var log = [];

// ── 1. CH-004 → RED hard-stop ────────────────────────────────────────────────
(function () {
  var m = mod('child');
  var idx = (m.yellow_rules || []).findIndex(function (r) { return r.ruleId === 'CH-004'; });
  if (idx >= 0) {
    var r = m.yellow_rules.splice(idx, 1)[0];
    r.band = 'RED';
    r.priority = 1;
    r.referral = 'FRU / DH immediately';
    r.action_bn = 'খেতে বা দুধ খেতে একদম অস্বীকার = IMNCI সাধারণ বিপদচিহ্ন। এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।';
    r.action_en = 'Complete refusal to eat/feed = IMNCI general danger sign. Call 108 and take to FRU now.';
    r.suspected_conditions = ['Very severe disease', 'Feeding refusal'];
    r.danger_signs = ['Not able to drink or feed'];
    r.clinical_sign_off_pending = true;
    r.status = 'draft';
    addRule(m, 'hard_stop_rules', r);
    setScore(m, 'c4', 3);
    log.push('CH-004 child: YELLOW→RED hard-stop, score c4 1→3');
  } else {
    log.push('CH-004 NOT FOUND in child.yellow_rules (already moved?)');
  }
})();

// ── 2. ANC-009R fever + rigors → RED (new question p9r) ───────────────────────
(function () {
  var m = mod('pregnancy');
  addQuestion(m, {
    id: 'p9r',
    text_bn: 'জ্বরের সাথে কাঁপুনি বা শীত-শীত ভাব আছে?',
    text_en: 'Fever WITH chills or rigors?',
    options: ['হ্যাঁ', 'না'],
  });
  addRule(m, 'hard_stop_rules', {
    ruleId: 'ANC-009R',
    priority: 1,
    condition_set: [{ question_id: 'p9r', operator: 'EQUALS', value: true }],
    band: 'RED',
    referral: 'FRU / DH immediately by 108',
    action_bn: 'গর্ভাবস্থায় জ্বরের সাথে কাঁপুনি = ম্যালেরিয়া বা মারাত্মক সংক্রমণ (সেপসিস) হতে পারে। বাম কাতে শোয়ান, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    action_en: 'Fever with rigors in pregnancy = possible malaria or sepsis. Lay on left side, call 108 and take to FRU now.',
    suspected_conditions: ['Malaria', 'Maternal sepsis / chorioamnionitis'],
    danger_signs: ['Fever with rigors/chills'],
    clinical_sign_off_pending: true,
    status: 'draft',
  });
  setScore(m, 'p9r', 4);
  log.push('ANC-009R pregnancy: added q p9r + RED hard-stop, score 4');
})();

// ── 3. PNC-006S severe postpartum dizziness/fainting → RED (new q pp6s) ───────
(function () {
  var m = mod('delivery_pnc');
  addQuestion(m, {
    id: 'pp6s',
    text_bn: 'মাথা ঘুরে পড়ে যাচ্ছেন, নাকি দাঁড়াতেও পারছেন না (তীব্র দুর্বলতা)?',
    text_en: 'Fainting / collapsing, or unable to stand (severe weakness)?',
    options: ['হ্যাঁ', 'না'],
  });
  addRule(m, 'hard_stop_rules', {
    ruleId: 'PNC-006S',
    priority: 1,
    condition_set: [{ question_id: 'pp6s', operator: 'EQUALS', value: true }],
    band: 'RED',
    referral: 'FRU / DH via 108 now',
    action_bn: 'প্রসবের পর তীব্র মাথা ঘোরা/অজ্ঞান-ভাব = লুকানো রক্তক্ষরণ বা শক হতে পারে। পা উঁচু করে শোয়ান, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    action_en: 'Severe postpartum dizziness/collapse = possible concealed bleeding or shock. Lay flat with legs raised, call 108 and take to FRU now.',
    suspected_conditions: ['Concealed PPH', 'Hypovolaemic shock'],
    danger_signs: ['Severe postpartum dizziness / collapse'],
    clinical_sign_off_pending: true,
    status: 'draft',
  });
  setScore(m, 'pp6s', 4);
  log.push('PNC-006S delivery_pnc: added q pp6s + RED hard-stop, score 4');
})();

// ── 4. CH-013 chest indrawing / stridor → RED (new q c13) ─────────────────────
(function () {
  var m = mod('child');
  addQuestion(m, {
    id: 'c13',
    text_bn: 'বুকের নিচের অংশ ভেতরে ঢুকে যাচ্ছে, বা বিশ্রামেও শ্বাসের শব্দ (stridor)?',
    text_en: 'Lower chest indrawing, or stridor at rest?',
    options: ['হ্যাঁ', 'না'],
  });
  addRule(m, 'hard_stop_rules', {
    ruleId: 'CH-013',
    priority: 1,
    condition_set: [{ question_id: 'c13', operator: 'EQUALS', value: true }],
    band: 'RED',
    referral: 'FRU / DH immediately',
    action_bn: 'বুক ভেতরে ঢোকা বা বিশ্রামেও শ্বাসের শব্দ = গুরুতর নিউমোনিয়া। শিশুকে শান্ত রাখুন, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    action_en: 'Lower chest indrawing or stridor at rest = severe pneumonia / very severe disease. Keep the child calm, call 108 and take to FRU now.',
    suspected_conditions: ['Severe pneumonia / very severe disease'],
    danger_signs: ['Chest indrawing', 'Stridor at rest'],
    clinical_sign_off_pending: true,
    status: 'draft',
  });
  setScore(m, 'c13', 4);
  log.push('CH-013 child: added q c13 + RED hard-stop, score 4');
})();

fs.writeFileSync(FILE, JSON.stringify(eng, null, 2) + '\n', 'utf8');
console.log('Applied v4 DRAFT rules (clinical_sign_off_pending):');
log.forEach(function (s) { console.log('  ✓ ' + s); });
