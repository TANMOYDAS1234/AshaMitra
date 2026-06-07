// Merges the genuinely-NEW v3 DRAFT clinical rules into the LIVE engine
// (assets/data/asha_engine.json, the file RuleExecutor actually runs).
//
// Strategy (per user choice): MERGE — add only what's missing, as yes/no
// boolean rules matching the live engine's model. Rules already present in
// v2.1.0 (newborn/child convulsions+lethargy, postpartum eclampsia PNC-007,
// postpartum breathing PNC-008, numeric thresholds for hypothermia/RR/MUAC/
// BP/Hb/PROM/GDM/FHR, etc.) are NOT duplicated.
//
// Every added rule is tagged clinical_sign_off_pending:true + status:"draft"
// + source:"v3_draft" for provenance (these are unvalidated until committee
// sign-off). The engine reads clinical_sign_off_pending; status/source are
// ignored by Dart (safe extra fields).
//
//   node docs/apply_v3_rules.js   ->  rewrites assets/data/asha_engine.json

const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, '..', 'ashamitra', 'assets', 'data', 'asha_engine.json');
const eng = JSON.parse(fs.readFileSync(FILE, 'utf8'));

const mod = (id) => {
  const m = eng.modules.find((x) => x.module_id === id);
  if (!m) throw new Error('module not found: ' + id);
  return m;
};
const haveQ = (m, id) => (m.questions || []).some((q) => q.id === id);
const haveRule = (m, id) =>
  ['hard_stop_rules', 'combination_rules', 'yellow_rules', 'numeric_rules']
    .some((k) => (m[k] || []).some((r) => r.ruleId === id));

let addedQ = 0, addedR = 0;
const addQ = (m, q) => { if (!haveQ(m, q.id)) { m.questions.push(q); addedQ++; } };
const addScore = (m, id, score) => {
  m.risk_engine = m.risk_engine || { score_rules: [], thresholds: {} };
  m.risk_engine.score_rules = m.risk_engine.score_rules || [];
  if (!m.risk_engine.score_rules.some((s) => s.condition === id))
    m.risk_engine.score_rules.push({ condition: id, score });
};
// draft-tagged rule factory
const R = (o) => ({
  ruleId: o.ruleId,
  ...(o.priority != null ? { priority: o.priority } : {}),
  clinical_sign_off_pending: true,
  status: 'draft',
  source: 'v3_draft',
  condition_set: [{ question_id: o.q, operator: 'EQUALS', value: true }],
  band: o.band,
  referral: o.referral,
  action_bn: o.action_bn,
  action_en: o.action_en,
  suspected_conditions: o.suspected,
  danger_signs: o.danger,
});
const addRule = (m, key, rule) => {
  if (haveRule(m, rule.ruleId)) return;
  m[key] = m[key] || [];
  m[key].push(rule);
  addedR++;
};

// ── NEWBORN ────────────────────────────────────────────────────────────────
{
  const m = mod('newborn');
  addQ(m, { id: 'n8',  text_bn: 'শিশুর শরীর ঠান্ডা লাগছে বা স্বাভাবিকের চেয়ে কম গরম?', text_en: 'Is the baby cold to touch / colder than normal (hypothermia)?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'n9',  text_bn: 'ত্বকে অনেক ফুসকুড়ি/পুঁজভরা ফোস্কা, বা কান থেকে পুঁজ পড়ছে?', text_en: 'Many skin pustules / pus-filled blisters, or pus draining from ear?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'n10', text_bn: 'মাথার নরম অংশ (তালু) ফুলে উঁচু হয়ে আছে?', text_en: 'Is the soft spot on the head (fontanelle) bulging?', options: ['হ্যাঁ', 'না'] });
  addRule(m, 'hard_stop_rules', R({ ruleId: 'NB-008', priority: 8, q: 'n8', band: 'RED', referral: 'SNCU / FRU immediately',
    action_bn: 'PSBI হার্ড-স্টপ। শরীর গরম রাখুন (ত্বক-থেকে-ত্বক/কাঙ্গারু কেয়ার), মাথা ঢেকে রাখুন। এখনই SNCU/FRU-তে রেফার করুন। হাইপোথার্মিয়া নবজাতকের বড় ঝুঁকি।',
    action_en: 'PSBI hard-stop. Keep warm (skin-to-skin/kangaroo care), cover head. Refer SNCU/FRU immediately. Hypothermia is a major neonatal killer.',
    suspected: ['Neonatal hypothermia'], danger: ['Hypothermia', 'Cold to touch'] }));
  addRule(m, 'hard_stop_rules', R({ ruleId: 'NB-010', priority: 9, q: 'n9', band: 'RED', referral: 'FRU / DH immediately',
    action_bn: 'অনেক ফুসকুড়ি/পুঁজভরা ফোস্কা বা কানে পুঁজ = PSBI স্থানীয় ব্যাকটেরিয়াল সংক্রমণ। এখনই FRU/DH-তে রেফার করুন।',
    action_en: 'Many pustules/pus-filled blisters or ear pus = PSBI local bacterial infection. Refer FRU/DH immediately.',
    suspected: ['Local bacterial infection (PSBI)'], danger: ['Skin pustules', 'Ear discharge'] }));
  addRule(m, 'hard_stop_rules', R({ ruleId: 'NB-011', priority: 10, q: 'n10', band: 'RED', referral: 'SNCU / FRU immediately',
    action_bn: 'মাথার তালু ফুলে থাকা = মেনিনজাইটিসের সম্ভাবনা। এখনই SNCU/FRU-তে রেফার করুন।',
    action_en: 'Bulging fontanelle = possible meningitis. Refer SNCU/FRU immediately.',
    suspected: ['Meningitis'], danger: ['Bulging fontanelle'] }));
  addScore(m, 'n8', 3); addScore(m, 'n9', 2); addScore(m, 'n10', 3);
}

// ── CHILD (2 m–5 y) ──────────────────────────────────────────────────────────
{
  const m = mod('child');
  addQ(m, { id: 'c9',  text_bn: 'যা-ই খাচ্ছে সব বমি করে ফেলছে?', text_en: 'Does the child vomit everything?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'c10', text_bn: 'ঘাড় শক্ত, আলোয় কষ্ট, বা জ্বরসহ প্রচণ্ড মাথাব্যথা?', text_en: 'Stiff neck, light sensitivity, or severe headache with fever?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'c11', text_bn: 'পায়খানার সাথে রক্ত যাচ্ছে?', text_en: 'Is there blood in the stool (dysentery)?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'c12', text_bn: 'হাতের তালু বা চোখের পাতা খুব ফ্যাকাশে?', text_en: 'Are the palms or inner eyelids very pale (anaemia)?', options: ['হ্যাঁ', 'না'] });
  addRule(m, 'hard_stop_rules', R({ ruleId: 'CH-009', priority: 5, q: 'c9', band: 'RED', referral: 'FRU / DH immediately',
    action_bn: 'সব বমি করে ফেলা = IMNCI সাধারণ বিপদচিহ্ন। মুখে কিছু রাখতে পারছে না — এখনই FRU/DH-তে রেফার করুন।',
    action_en: 'Vomiting everything = IMNCI general danger sign. Cannot keep anything down — refer FRU/DH immediately.',
    suspected: ['Unable to retain feeds', 'Possible serious illness'], danger: ['Vomits everything'] }));
  addRule(m, 'hard_stop_rules', R({ ruleId: 'CH-010', priority: 6, q: 'c10', band: 'RED', referral: 'FRU / DH immediately',
    action_bn: 'ঘাড় শক্ত/জ্বরসহ প্রচণ্ড মাথাব্যথা = মেনিনজাইটিস/এনসেফালাইটিসের সম্ভাবনা। ১০৮ কল করুন, এখনই FRU/DH-তে রেফার করুন।',
    action_en: 'Stiff neck/severe headache with fever = possible meningitis/encephalitis. Call 108, refer FRU/DH immediately.',
    suspected: ['Meningitis', 'Encephalitis'], danger: ['Neck stiffness', 'Severe headache with fever'] }));
  addRule(m, 'yellow_rules', R({ ruleId: 'CH-011', priority: 5, q: 'c11', band: 'YELLOW', referral: 'PHC within 24 h',
    action_bn: 'পায়খানায় রক্ত = ডিসেন্ট্রি, অ্যান্টিবায়োটিক দরকার। ২৪ ঘণ্টার মধ্যে PHC। পানিশূন্যতা/নিস্তেজতা থাকলে = FRU।',
    action_en: 'Blood in stool = dysentery, needs antibiotics. Refer PHC within 24 h. With dehydration/lethargy = FRU.',
    suspected: ['Dysentery'], danger: ['Blood in stool'] }));
  addRule(m, 'yellow_rules', R({ ruleId: 'CH-012', priority: 6, q: 'c12', band: 'YELLOW', referral: 'PHC for Hb check',
    action_bn: 'ফ্যাকাশে = রক্তাল্পতা। Hb পরীক্ষার জন্য PHC-তে রেফার করুন। গুরুতর ফ্যাকাশে = FRU (সম্ভাব্য রক্ত সঞ্চালন)।',
    action_en: 'Pallor = anaemia. Refer PHC for Hb. Severe pallor = FRU (possible transfusion).',
    suspected: ['Anaemia'], danger: ['Pallor'] }));
  addScore(m, 'c9', 3); addScore(m, 'c10', 3); addScore(m, 'c11', 2); addScore(m, 'c12', 2);
}

// ── PREGNANCY (ANC) ──────────────────────────────────────────────────────────
{
  const m = mod('pregnancy');
  addQ(m, { id: 'p8',  text_bn: 'খুব ফ্যাকাশে, দুর্বল, বা সামান্য পরিশ্রমেই হাঁপিয়ে যাচ্ছেন?', text_en: 'Very pale, weak, or breathless on slight exertion (severe anaemia)?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'p9',  text_bn: 'জ্বর, বিশেষ করে কাঁপুনি দিয়ে জ্বর আসছে?', text_en: 'Fever, especially with chills/rigors?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'p10', text_bn: 'যোনিপথে হঠাৎ জল ভেঙেছে বা ক্রমাগত জল ঝরছে?', text_en: 'Sudden gush or continuous leaking of fluid (PROM)?', options: ['হ্যাঁ', 'না'] });
  addRule(m, 'hard_stop_rules', R({ ruleId: 'ANC-008', priority: 6, q: 'p8', band: 'RED', referral: 'FRU / DH',
    action_bn: 'গুরুতর রক্তাল্পতা মাতৃমৃত্যুর বড় কারণ। গুরুতর ফ্যাকাশে/হাঁপানি = Hb পরীক্ষা ও রক্ত সঞ্চালনের পরিকল্পনার জন্য FRU/DH-তে রেফার করুন।',
    action_en: 'Severe anaemia is a leading maternal killer. Severe pallor/breathlessness = refer FRU/DH for Hb + transfusion planning.',
    suspected: ['Severe anaemia in pregnancy'], danger: ['Severe pallor', 'Breathlessness on exertion'] }));
  addRule(m, 'hard_stop_rules', R({ ruleId: 'ANC-009', priority: 7, q: 'p9', band: 'RED', referral: 'FRU / DH immediately',
    action_bn: 'গর্ভাবস্থায় উচ্চ জ্বর/কাঁপুনি = সেপসিস/ম্যালেরিয়া/ক্রিয়োঅ্যামনিওনাইটিসের ঝুঁকি। এখনই FRU/DH-তে রেফার করুন।',
    action_en: 'High fever/rigors in pregnancy = sepsis/malaria/chorioamnionitis risk. Refer FRU/DH immediately.',
    suspected: ['Maternal sepsis', 'Malaria in pregnancy', 'Chorioamnionitis'], danger: ['Fever with rigors'] }));
  addRule(m, 'hard_stop_rules', R({ ruleId: 'ANC-010', priority: 8, q: 'p10', band: 'RED', referral: 'FRU / DH',
    action_bn: 'হঠাৎ জল ভাঙা/ক্রমাগত লিকেজ = PROM, সংক্রমণ/প্রিটার্ম প্রসবের ঝুঁকি। যোনি পরীক্ষা করবেন না, পরিষ্কার প্যাড রাখুন, FRU/DH-তে রেফার করুন।',
    action_en: 'Sudden gush/continuous leaking = PROM, infection/preterm-labour risk. No vaginal exam, keep a clean pad, refer FRU/DH.',
    suspected: ['Premature rupture of membranes'], danger: ['Leaking liquor'] }));
  addScore(m, 'p8', 3); addScore(m, 'p9', 3); addScore(m, 'p10', 3);
}

// ── POSTPARTUM (delivery_pnc) ────────────────────────────────────────────────
{
  const m = mod('delivery_pnc');
  addQ(m, { id: 'pp9', text_bn: 'মন খুব খারাপ, কান্না, ঘুম/খাওয়া কমে যাওয়া, বা বাচ্চার প্রতি আগ্রহ নেই?', text_en: 'Persistent low mood, crying, sleep/appetite loss, or no interest in the baby?', options: ['হ্যাঁ', 'না'] });
  addRule(m, 'yellow_rules', R({ ruleId: 'PNC-009', priority: 6, q: 'pp9', band: 'YELLOW', referral: 'PHC / MO counselling',
    action_bn: 'প্রসব-পরবর্তী বিষণ্নতার স্ক্রিন। পরামর্শ দিন, পরিবারকে যুক্ত করুন, PHC/MO-তে রেফার করুন। নিজের বা বাচ্চার ক্ষতির চিন্তা থাকলে = জরুরি রেফারেল।',
    action_en: 'Postpartum depression screen. Counsel, involve family, refer PHC/MO. Any thought of self-harm or harming the baby = urgent referral.',
    suspected: ['Postpartum depression'], danger: ['Low mood', 'Anhedonia'] }));
  addScore(m, 'pp9', 1);
}

// ── IMMUNISATION (UIP corrections + AEFI) ───────────────────────────────────
{
  const m = mod('immunisation');
  // MMR -> MR (India UIP uses Measles–Rubella, no mumps)
  const q2 = m.questions.find((q) => q.id === 'im2');
  if (q2) q2.options = q2.options.map((o) => (o === 'Measles/MMR' ? 'Measles/MR' : o));
  const imm2 = (m.yellow_rules || []).find((r) => r.ruleId === 'IMM-002');
  if (imm2) imm2.condition_set.forEach((c) => {
    if (Array.isArray(c.value)) c.value = c.value.map((v) => (v === 'Measles/MMR' ? 'Measles/MR' : v));
  });
  const imm1 = (m.yellow_rules || []).find((r) => r.ruleId === 'IMM-001');
  if (imm1 && !/PCV/.test(imm1.action_en)) {
    imm1.action_en += ' Includes PCV, Rotavirus (RVV) and fIPV per current UIP.';
    imm1.action_bn += ' বর্তমান UIP অনুযায়ী PCV, রোটাভাইরাস (RVV) ও fIPV অন্তর্ভুক্ত।';
  }
  const imm3 = (m.yellow_rules || []).find((r) => r.ruleId === 'IMM-003');
  if (imm3) {
    imm3.action_en = imm3.action_en.replace('MMR 15–18 m', 'MR-2 16–24 m');
    imm3.action_bn = imm3.action_bn.replace('MMR ১৫-১৮ মাসে', 'MR-2 ১৬-২৪ মাসে');
  }
  addQ(m, { id: 'im6', text_bn: 'আগের টিকার পর কি গুরুতর প্রতিক্রিয়া হয়েছিল?', text_en: 'Was there a severe reaction after a previous vaccine dose (AEFI)?', options: ['হ্যাঁ', 'না'] });
  addRule(m, 'yellow_rules', R({ ruleId: 'IMM-006', priority: 6, q: 'im6', band: 'YELLOW', referral: 'Refer MO before next dose',
    action_bn: 'আগের ডোজে গুরুতর প্রতিক্রিয়া (AEFI)। পরের ডোজের আগে MO-কে দেখান — স্বয়ংক্রিয়ভাবে নির্ধারণ করবেন না।',
    action_en: 'Severe reaction after a previous dose (AEFI). Refer to MO before the next dose — do not auto-schedule.',
    suspected: ['AEFI history'], danger: ['Prior severe vaccine reaction'] }));
  addScore(m, 'im6', 1);
}

// ── EMERGENCY (rural killers) ────────────────────────────────────────────────
{
  const m = mod('emergency');
  addQ(m, { id: 'e5', text_bn: 'সাপে কামড়েছে, বিষাক্ত পোকা বা পশুর কামড়?', text_en: 'Snakebite, venomous sting, or animal bite?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'e6', text_bn: 'বিষ/কীটনাশক/অতিরিক্ত ওষুধ খেয়েছে বা খাওয়ানো হয়েছে?', text_en: 'Poison, pesticide, or overdose ingested?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'e7', text_bn: 'ঠান্ডা-ঘামে ভেজা, খুব দুর্বল নাড়ি, অত্যন্ত নিস্তেজ (শকের লক্ষণ)?', text_en: 'Cold clammy skin, very weak pulse, extreme listlessness (shock)?', options: ['হ্যাঁ', 'না'] });
  addQ(m, { id: 'e8', text_bn: 'গুরুতর আঘাত, বড় ক্ষত থেকে রক্তপাত, বা মারাত্মক পোড়া?', text_en: 'Major injury, bleeding from a large wound, or severe burn?', options: ['হ্যাঁ', 'না'] });
  addRule(m, 'hard_stop_rules', R({ ruleId: 'EM-006', priority: 5, q: 'e5', band: 'RED', referral: 'FRU / DH ≤ 30 min',
    action_bn: 'হার্ড-স্টপ। অঙ্গ স্থির রাখুন (স্প্লিন্ট), হৃদয়ের নিচে রাখুন, টাইট জিনিস খুলুন। কাটবেন/চুষবেন/বাঁধবেন না। ১০৮ কল করুন, FRU/DH ≤ ৩০ মিনিট (অ্যান্টি-স্নেক-ভেনম)। পশুর কামড় হলে ১৫ মিনিট ক্ষত ধুয়ে ARV/RIG।',
    action_en: 'Hard-stop. Immobilise the limb (splint), keep below heart level, remove tight items. Do NOT cut/suck/tourniquet. Call 108, FRU/DH ≤30 min (anti-snake-venom). Animal bite: wound wash 15 min + ARV/RIG.',
    suspected: ['Envenomation', 'Rabies risk'], danger: ['Snakebite', 'Animal bite'] }));
  addRule(m, 'hard_stop_rules', R({ ruleId: 'EM-007', priority: 6, q: 'e6', band: 'RED', referral: 'FRU / DH ≤ 30 min',
    action_bn: 'হার্ড-স্টপ। বমি করাবেন না। কৌটা/লেবেল সঙ্গে নিন। শ্বাসনালী রক্ষা করুন, অজ্ঞান হলে বাম কাতে শোয়ান। ১০৮ কল করুন, FRU/DH ≤ ৩০ মিনিট।',
    action_en: 'Hard-stop. Do NOT induce vomiting. Bring the container/label. Protect airway, left-lateral if drowsy. Call 108, FRU/DH ≤30 min.',
    suspected: ['Poisoning / pesticide ingestion'], danger: ['Ingested poison/overdose'] }));
  addRule(m, 'hard_stop_rules', R({ ruleId: 'EM-008', priority: 7, q: 'e7', band: 'RED', referral: 'FRU / DH ≤ 30 min',
    action_bn: 'হার্ড-স্টপ। সমতল শোয়ান, গরম রাখুন, পা উঁচু করুন, মুখে কিছু দেবেন না। ১০৮ কল করুন, FRU/DH ≤ ৩০ মিনিট।',
    action_en: 'Hard-stop. Lay flat, keep warm, raise legs, nothing by mouth. Call 108, FRU/DH ≤30 min.',
    suspected: ['Shock / circulatory collapse'], danger: ['Cold clammy skin', 'Weak pulse'] }));
  addRule(m, 'hard_stop_rules', R({ ruleId: 'EM-009', priority: 8, q: 'e8', band: 'RED', referral: 'FRU / DH ≤ 30 min',
    action_bn: 'হার্ড-স্টপ। রক্তপাতে সরাসরি চাপ দিন; পোড়ায় পরিষ্কার জল দিয়ে ঠান্ডা করুন, ঢেকে দিন, কিছু লাগাবেন না। ভাঙা হাড় স্থির রাখুন। ১০৮ কল করুন, FRU/DH ≤ ৩০ মিনিট।',
    action_en: 'Hard-stop. Direct pressure on bleeding; for burns cool with clean water, cover, apply nothing. Immobilise fractures. Call 108, FRU/DH ≤30 min.',
    suspected: ['Major trauma', 'Severe burn'], danger: ['Major injury', 'Severe bleeding', 'Burn'] }));
  addScore(m, 'e5', 4); addScore(m, 'e6', 4); addScore(m, 'e7', 4); addScore(m, 'e8', 4);
}

// ── metadata ────────────────────────────────────────────────────────────────
eng.version = '2.2.0-draft';
eng.v3_merge = {
  applied: 'v3 DRAFT genuinely-new rules merged into live engine',
  note: 'All rules flagged clinical_sign_off_pending are unvalidated pending AIIH&PH / WB Health Secretariat sign-off.',
  added_questions: addedQ,
  added_rules: addedR,
};

fs.writeFileSync(FILE, JSON.stringify(eng, null, 2) + '\n', 'utf8');
console.log(`asha_engine.json updated -> version ${eng.version}`);
console.log(`Added ${addedQ} questions and ${addedR} rules.`);
