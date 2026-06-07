// Generates a clinical sign-off checklist (markdown) of every DRAFT rule
// (clinical_sign_off_pending) in the live engine, for the AIIH&PH / WB Health
// Secretariat committee. This is the ARTIFACT only — the clinical validation
// must be done by the committee.
//   node docs/gen_signoff_checklist.js  ->  docs/AshaMitra_SignOff_Checklist.md

var fs = require('fs');
var path = require('path');
var FILE = path.join(__dirname, '..', 'ashamitra', 'assets', 'data', 'asha_engine.json');
var OUT = path.join(__dirname, 'AshaMitra_SignOff_Checklist.md');
var eng = JSON.parse(fs.readFileSync(FILE, 'utf8'));

var TITLE = {
  newborn: 'Newborn (0-28 d)', child: 'Child (1-5 y)',
  pregnancy: 'Pregnancy (ANC)', delivery_pnc: 'Postpartum',
  immunisation: 'Immunization', emergency: 'Emergency',
};
var OP = { EQUALS: '=', GREATER_THAN: '>', LESS_THAN: '<', GREATER_THAN_OR_EQUAL: '>=', LESS_THAN_OR_EQUAL: '<=', BETWEEN: 'between', IN: 'in' };

function condText(r, qmap) {
  return (r.condition_set || []).map(function (c) {
    if (c.vital != null) {
      var v = Array.isArray(c.value) ? '[' + c.value.join('-') + ']' : c.value;
      return c.vital + ' ' + (OP[c.operator] || c.operator) + ' ' + v;
    }
    var q = qmap[c.question_id];
    var label = q ? ('"' + q.text_en + '"') : c.question_id;
    var val = c.value === true ? 'Yes' : c.value === false ? 'No'
      : Array.isArray(c.value) ? c.value.join('/') : c.value;
    return label + ' = ' + val;
  }).join(' AND ');
}

var rows = 0;
var out = [];
out.push('# AshaMitra - Clinical Sign-off Checklist');
out.push('');
out.push('Engine ' + eng.version + '. Every rule below is DRAFT (clinical_sign_off_pending) - live in the app but NOT clinically validated. For each, the committee marks Approve / Adjust / Reject and confirms: clinically correct, correct band, correct referral, within ASHA scope, plain Bengali wording.');
out.push('');

for (var i = 0; i < eng.modules.length; i++) {
  var m = eng.modules[i];
  var qmap = {};
  (m.questions || []).forEach(function (q) { qmap[q.id] = q; });
  var draft = [];
  var arrays = [['hard_stop_rules', 'RED hard-stop'], ['combination_rules', 'combination'], ['numeric_rules', 'measurement'], ['yellow_rules', 'YELLOW']];
  for (var a = 0; a < arrays.length; a++) {
    var k = arrays[a][0], kind = arrays[a][1];
    (m[k] || []).forEach(function (r) {
      if (r.clinical_sign_off_pending || r.status === 'draft') draft.push([r, kind]);
    });
  }
  if (!draft.length) continue;
  out.push('## ' + (TITLE[m.module_id] || m.module_id) + '  (' + draft.length + ' draft)');
  out.push('');
  out.push('| Rule | Band | Fires when | Action / referral | Approve | Adjust | Reject | Note |');
  out.push('|---|---|---|---|:--:|:--:|:--:|---|');
  for (var d = 0; d < draft.length; d++) {
    var r = draft[d][0], kind2 = draft[d][1];
    rows++;
    var action = (r.action_en || '').split('|').join('/');
    var ref = r.referral ? (' -> ' + r.referral) : '';
    out.push('| `' + r.ruleId + '` (' + kind2 + ') | ' + r.band + ' | ' +
      condText(r, qmap).split('|').join('/') + ' | ' + action + ref + ' | [ ] | [ ] | [ ] |  |');
  }
  out.push('');
}

out.push('---');
out.push('');
out.push('Total draft rules awaiting sign-off: ' + rows + '.');
out.push('');
out.push('Sign-off: ____________ (AIIH&PH)   ____________ (WB Health Secretariat)   Date: ________');

fs.writeFileSync(OUT, out.join('\n') + '\n', 'utf8');
console.log('Wrote ' + OUT + ' - ' + rows + ' draft rules across ' + eng.modules.length + ' modules.');
