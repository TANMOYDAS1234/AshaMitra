// Draft de-escalation: isolated fever in pregnancy was a flat RED hard-stop
// (any "জ্বর হয়েছে" → 108/FRU). That over-triages a mild fever. Move ANC-009
// (p9 fever) from hard_stop → yellow (PHC within 24h); the action still tells
// the worker to go FRU if there are rigors / very high fever / other signs.
// Other RED danger signs (convulsion, bleeding, etc.) are unchanged.
//   node docs/apply_fever_yellow.js

const fs = require('fs');
const path = require('path');
const FILE = path.join(__dirname, '..', 'ashamitra', 'assets', 'data', 'asha_engine.json');
const eng = JSON.parse(fs.readFileSync(FILE, 'utf8'));
const preg = eng.modules.find((m) => m.module_id === 'pregnancy');
if (!preg) throw new Error('pregnancy module missing');

const i = (preg.hard_stop_rules || []).findIndex((r) => r.ruleId === 'ANC-009');
if (i >= 0) {
  preg.hard_stop_rules.splice(i, 1); // remove from hard-stop (RED)
}
preg.yellow_rules = preg.yellow_rules || [];
if (!preg.yellow_rules.some((r) => r.ruleId === 'ANC-009')) {
  preg.yellow_rules.push({
    ruleId: 'ANC-009',
    priority: preg.yellow_rules.length + 1,
    clinical_sign_off_pending: true,
    status: 'draft',
    source: 'v3_draft',
    condition_set: [{ question_id: 'p9', operator: 'EQUALS', value: true }],
    band: 'YELLOW',
    referral: 'PHC within 24 h',
    action_bn: 'গর্ভাবস্থায় জ্বর — ২৪ ঘণ্টার মধ্যে PHC-তে দেখান (ম্যালেরিয়া/UTI/সংক্রমণ পরীক্ষা)। কাঁপুনি দিয়ে জ্বর, খুব বেশি জ্বর, বা অন্য বিপদচিহ্নের সাথে হলে = এখনই FRU/DH।',
    action_en: 'Fever in pregnancy — refer PHC within 24 h (check malaria/UTI/infection). With rigors, very high fever, or any other danger sign = FRU/DH now.',
    suspected_conditions: ['Fever in pregnancy (rule out malaria/UTI/sepsis)'],
    danger_signs: ['Fever'],
  });
}

eng.version = '2.4.0-draft';
fs.writeFileSync(FILE, JSON.stringify(eng, null, 2) + '\n', 'utf8');
console.log(`pregnancy fever (ANC-009) moved to YELLOW. engine ${eng.version}`);
