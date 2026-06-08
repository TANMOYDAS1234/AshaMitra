// Clinical-audit remediation (round 1): remove ASHA out-of-scope drug / injection
// / procedure instructions from rule ACTION text. BANDS ARE UNCHANGED — only the
// "what the ASHA should do" wording is replaced with in-scope first aid + 108 +
// refer + notify ANM/MO. Source: multi-agent clinical audit (22 critical + 39
// major findings); this script applies ONLY the unambiguous scope/safety
// breaches. Band changes, new danger-sign questions and threshold tuning are
// documented for the clinical sign-off committee, NOT applied here.
//   node docs/apply_scope_fixes.js

var fs = require('fs');
var path = require('path');
var FILE = path.join(__dirname, '..', 'ashamitra', 'assets', 'data', 'asha_engine.json');
var eng = JSON.parse(fs.readFileSync(FILE, 'utf8'));

var FIX = {
  'NB-COMB-004': {
    bn: 'নাভি সংক্রমণ + জ্বর = সিস্টেমিক সেপসিসের ঝুঁকি (PSBI)। শিশুকে গরম রাখুন, বুকের দুধ খাওয়ানো চালিয়ে যান, এখনই ১০৮ ডেকে SNCU/FRU-তে নিয়ে যান এবং ANM/MO-কে জানান। নিজে কোনো ওষুধ দেবেন না।',
    en: 'Umbilical infection + fever = systemic sepsis risk (PSBI). Keep the baby warm, keep breastfeeding, call 108 and take to SNCU/FRU now, and inform the ANM/MO. Do not give any medicine yourself.',
  },
  'NB-COMB-005': {
    bn: 'দুধ না খাওয়া + জ্বর = সম্ভাব্য গুরুতর সংক্রমণ (PSBI)। শিশুকে গরম রাখুন, বুকের দুধ খাওয়ানোর চেষ্টা চালিয়ে যান, এখনই ১০৮ ডেকে SNCU/FRU-তে নিয়ে যান এবং ANM/MO-কে জানান। নিজে কোনো ওষুধ বা ইনজেকশন দেবেন না।',
    en: 'Not feeding + fever = possible serious infection (PSBI). Keep the baby warm, keep trying to breastfeed, call 108 and take to SNCU/FRU now, and inform the ANM/MO. Do not give any medicine or injection yourself.',
  },
  'CH-005': {
    bn: 'গুরুতর পানিশূন্যতা = RED। শিশু গিলতে পারলে চামচে ORS দিন (অজ্ঞান বা গিলতে না পারলে নয়)। এখনই ১০৮ ডেকে IV তরলের জন্য FRU-তে নিয়ে যান।',
    en: 'Severe dehydration = RED. If the child can swallow, give ORS by spoon (NOT if unconscious or unable to swallow). Call 108 and take to FRU for IV fluids now.',
  },
  'CH-COMB-003': {
    bn: 'ডায়রিয়া + খেতে অস্বীকার = গুরুতর পানিশূন্যতার ঝুঁকি। শিশু গিলতে পারলে চামচে ORS দিন, এখনই ১০৮ ডেকে FRU-তে রেফার করুন।',
    en: 'Diarrhoea + refusal to eat = severe dehydration risk. If the child can swallow, give ORS by spoon; call 108 and refer to FRU now.',
  },
  'CH-VITAL-008': {
    bn: 'SpO2 ৯০–৯৪% = মাঝারি হাইপক্সিয়া। শিশুকে শান্ত ও সোজা করে রাখুন, দ্রুত PHC-তে রেফার করুন।',
    en: 'SpO2 90–94% = moderate hypoxia. Keep the child calm and upright, refer to PHC promptly.',
  },
  'ANC-007': {
    bn: 'এক্লাম্পসিয়া হার্ড-স্টপ। খিঁচুনি = জীবনসংকটাপন্ন। বাম কাতে শোয়ান, আঘাত থেকে রক্ষা করুন ও শ্বাসনালী খোলা রাখুন, মুখে কিছু দেবেন না, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    en: 'Eclampsia hard-stop. Convulsion = life-threatening. Lay on left side, protect from injury and keep airway clear, give nothing by mouth, call 108 and take to FRU now.',
  },
  'ANC-COMB-004': {
    bn: 'উচ্চ BP + ঝাপসা দৃষ্টি = গুরুতর প্রি-এক্লাম্পসিয়া। বাম কাতে শোয়ান, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    en: 'High BP + blurred vision = severe pre-eclampsia. Lay on left side, call 108 and take to FRU now.',
  },
  'ANC-VITAL-005': {
    bn: 'সিস্টোলিক BP ≥ ১৬০ mmHg — গুরুতর হাইপারটেনশন। বাম কাতে শোয়ান, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    en: 'Systolic BP ≥ 160 mmHg — severe hypertension. Lay on left side, call 108 and take to FRU now.',
  },
  'ANC-VITAL-011': {
    bn: 'TSH > ১০ mIU/L রিপোর্টে = থাইরয়েড সমস্যা। PHC/MO-তে রেফার করুন — নিজে কোনো ওষুধ শুরু বা পরিবর্তন করবেন না।',
    en: 'TSH > 10 mIU/L on report = thyroid problem. Refer to PHC/MO — do not start or change any medicine yourself.',
  },
  'ANC-VITAL-012': {
    bn: 'TSH ২.৫–১০ mIU/L রিপোর্টে = থাইরয়েড একটু বেশি। PHC/MO-তে রেফার করুন; নিজে ওষুধ দেবেন না।',
    en: 'TSH 2.5–10 mIU/L on report = mildly raised thyroid. Refer to PHC/MO; do not give medicine yourself.',
  },
  'ANC-VITAL-013': {
    bn: 'রিপোর্টে সুগার বেশি (GDM)। GDM ব্যবস্থাপনার জন্য PHC/MO-তে রেফার করুন। ASHA-র কাজ: সুষম খাবারের পরামর্শ ও ফলো-আপ নিশ্চিত করা। নিজে ওষুধ বা ইনসুলিন দেবেন না।',
    en: 'High sugar on report (GDM). Refer to PHC/MO for GDM management. ASHA role: counsel balanced diet and ensure follow-up. Do not give medicine or insulin yourself.',
  },
  'PNC-001': {
    bn: 'PPH হার্ড-স্টপ। জরায়ুর উপরে পেটে শক্ত করে মালিশ করুন (fundal massage), মাকে শুইয়ে রাখুন, এখনই ১০৮ ডেকে FRU/DH-তে নিয়ে যান।',
    en: 'PPH hard-stop. Do firm external fundal massage over the uterus, lay the mother down, call 108 and take to FRU/DH now.',
  },
  'PNC-007': {
    bn: 'প্রসব-পরবর্তী এক্লাম্পসিয়া হার্ড-স্টপ। খিঁচুনি = জীবনসংকটাপন্ন। বাম কাতে শোয়ান, আঘাত থেকে রক্ষা করুন ও শ্বাসনালী খোলা রাখুন, মুখে কিছু দেবেন না, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    en: 'Postpartum eclampsia hard-stop. Convulsion = life-threatening. Lay on left side, protect from injury and keep airway clear, nothing by mouth, call 108 and take to FRU now.',
  },
  'PNC-VITAL-004': {
    bn: 'প্রসবের পর সিস্টোলিক BP ≥ ১৪০ = পোস্টপার্টাম প্রি-এক্লাম্পসিয়া। বাম কাতে শোয়ান, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    en: 'Postpartum systolic BP ≥ 140 = postpartum pre-eclampsia. Lay on left side, call 108 and take to FRU now.',
  },
  'PNC-VITAL-008': {
    bn: 'তাপমাত্রা ≥ ৩৮.৯°C প্রসবের পর = গুরুতর পিউরপেরাল সেপসিস। মাকে গরম ও পর্যাপ্ত পানি দিন, নিজে ওষুধ দেবেন না, এখনই ১০৮ ডেকে FRU-তে নিয়ে যান।',
    en: 'Temp ≥ 38.9°C postpartum = severe puerperal sepsis. Keep the mother warm and hydrated, do not give medicine yourself, call 108 and take to FRU now.',
  },
  'EM-001': {
    bn: 'হার্ড-স্টপ। এখনই ১০৮ কল করুন, ≤ ৩০ মিনিটে FRU/DH-তে নিয়ে যান। প্রসব-পরবর্তী রক্তপাত হলে জরায়ুর উপরে শক্ত করে মালিশ করুন (fundal massage)।',
    en: 'Hard-stop. Call 108 now, reach FRU/DH within 30 min. If postpartum bleeding, do firm external fundal massage over the uterus.',
  },
};

var applied = [];
var missing = Object.keys(FIX).slice();
for (var i = 0; i < eng.modules.length; i++) {
  var m = eng.modules[i];
  var arrs = ['hard_stop_rules', 'combination_rules', 'numeric_rules', 'yellow_rules'];
  for (var a = 0; a < arrs.length; a++) {
    var list = m[arrs[a]] || [];
    for (var r = 0; r < list.length; r++) {
      var rule = list[r];
      if (FIX[rule.ruleId]) {
        rule.action_bn = FIX[rule.ruleId].bn;
        rule.action_en = FIX[rule.ruleId].en;
        applied.push(rule.ruleId + ' (' + m.module_id + ', band ' + rule.band + ')');
        var mi = missing.indexOf(rule.ruleId);
        if (mi >= 0) missing.splice(mi, 1);
      }
    }
  }
}

fs.writeFileSync(FILE, JSON.stringify(eng, null, 2) + '\n', 'utf8');
console.log('Applied ' + applied.length + ' scope fixes (band unchanged):');
applied.forEach(function (s) { console.log('  ✓ ' + s); });
if (missing.length) console.log('NOT FOUND (check ruleId): ' + missing.join(', '));
