// Renders the LIVE engine (assets/data/asha_engine.json) to a print-ready
// clinical rulebook for sign-off — exactly the rules the app runs, with every
// unvalidated (clinical_sign_off_pending) rule flagged DRAFT. Includes the
// graded-answer + adaptive-layer behaviours that aren't in the JSON rules.
//
//   node docs/gen_live_rules_pdf.js  ->  docs/AshaMitra_Live_Rules.html

const fs = require('fs');
const path = require('path');
const FILE = path.join(__dirname, '..', 'ashamitra', 'assets', 'data', 'asha_engine.json');
const OUT = path.join(__dirname, 'AshaMitra_Live_Rules.html');
const eng = JSON.parse(fs.readFileSync(FILE, 'utf8'));

const esc = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const bandCls = (b) => ({ RED: 'red', YELLOW: 'yellow', GREEN: 'green' }[b] || 'green');
const badge = (b) => `<span class="badge ${bandCls(b)}">${esc(b)}</span>`;
const EMOJI = { newborn: '👶', child: '🧒', pregnancy: '🤰', delivery_pnc: '🤱', immunisation: '💉', emergency: '🚨' };
const OP = { EQUALS: '=', GREATER_THAN: '>', LESS_THAN: '<', GREATER_THAN_OR_EQUAL: '≥', LESS_THAN_OR_EQUAL: '≤', BETWEEN: 'between', IN: 'in' };

function readableCond(c, qmap) {
  if (c.vital != null) {
    const v = Array.isArray(c.value) ? `[${c.value.join('–')}]` : c.value;
    return `<code>${esc(c.vital)}</code> ${OP[c.operator] || c.operator} <b>${esc(v)}</b>`;
  }
  const q = qmap[c.question_id];
  const label = q ? `“${esc(q.text_en)}”` : `<code>${esc(c.question_id)}</code>`;
  if (c.operator === 'EQUALS') {
    const val = c.value === true ? 'Yes' : c.value === false ? 'No' : esc(c.value);
    return `${label} = <b>${val}</b>`;
  }
  if (c.operator === 'IN') return `${label} in <b>${(c.value || []).map(esc).join(' / ')}</b>`;
  return `${label} ${OP[c.operator] || c.operator} <b>${esc(c.value)}</b>`;
}

function ruleCard(r, kind, qmap) {
  const band = r.band || (kind === 'yellow' ? 'YELLOW' : 'RED');
  const draft = r.clinical_sign_off_pending || r.status === 'draft';
  const cond = (r.condition_set || []).map((c) => readableCond(c, qmap)).join(' <span class="and">AND</span> ');
  const chip = kind === 'hard' ? 'HARD-STOP' : kind === 'combo' ? 'COMBINATION' : kind === 'vital' ? 'MEASUREMENT' : 'SCORED';
  const signs = [...(r.danger_signs || [])].map(esc).join(' · ');
  const susp = [...(r.suspected_conditions || [])].map(esc).join(' · ');
  return `
  <div class="rule ${bandCls(band)}">
    <div class="rule-head">
      <span class="rid">${esc(r.ruleId)}</span>
      ${badge(band)}
      <span class="chip ${kind === 'yellow' ? 'soft' : 'hard'}">${chip}</span>
      ${draft ? '<span class="tag draft">DRAFT · SIGN-OFF</span>' : ''}
      ${r.referral ? `<span class="refer">→ ${esc(r.referral)}</span>` : ''}
    </div>
    <div class="cond"><span class="lbl">If</span> ${cond || '—'}</div>
    ${r.action_en ? `<div class="action"><span class="lbl">Action</span> ${esc(r.action_en)}</div>` : ''}
    ${r.action_bn ? `<div class="action-bn">${esc(r.action_bn)}</div>` : ''}
    ${susp ? `<div class="sub"><span class="lbl">Suspected</span> ${susp}</div>` : ''}
    ${signs ? `<div class="sub"><span class="lbl">Danger signs</span> ${signs}</div>` : ''}
  </div>`;
}

function moduleSection(m, idx) {
  const qmap = {};
  for (const q of (m.questions || [])) qmap[q.id] = q;
  const groups = [
    ['hard', m.hard_stop_rules || []],
    ['combo', m.combination_rules || []],
    ['vital', m.numeric_rules || []],
    ['yellow', m.yellow_rules || []],
  ];
  const total = groups.reduce((n, [, a]) => n + a.length, 0);
  const draftN = groups.reduce((n, [, a]) => n + a.filter((r) => r.clinical_sign_off_pending || r.status === 'draft').length, 0);
  const cards = groups.map(([k, arr]) => arr.map((r) => ruleCard(r, k, qmap)).join('')).join('');
  const th = m.risk_engine && m.risk_engine.thresholds ? m.risk_engine.thresholds : {};
  const thStr = Object.entries(th).map(([b, r]) => `${b} ${Array.isArray(r) && r.length === 2 ? r[0] + '–' + r[1] : '—'}`).join(' · ');
  const qlist = (m.questions || []).map((q) => `<tr><td><code>${esc(q.id)}</code></td><td>${esc(q.text_bn)}</td><td>${esc(q.text_en)}</td><td>${(q.options || []).map(esc).join(' · ')}</td></tr>`).join('');
  return `
  <section class="case">
    <h2>${idx}. ${EMOJI[m.module_id] || ''} ${esc(m.title_en)}</h2>
    <div class="case-meta">
      <span>${esc(m.title_bn)}</span>
      <span>Module <code>${esc(m.module_id)}</code></span>
      <span>${m.questions ? m.questions.length : 0} questions · ${total} rules${draftN ? ` · <b class="draftc">${draftN} draft</b>` : ''}</span>
    </div>
    <table class="q"><thead><tr><th>ID</th><th>প্রশ্ন (BN)</th><th>Question (EN)</th><th>Answers</th></tr></thead><tbody>${qlist}</tbody></table>
    ${cards}
    ${thStr ? `<div class="score"><span class="lbl">Risk-score bands</span> ${esc(thStr)}</div>` : ''}
  </section>`;
}

const allRules = eng.modules.flatMap((m) => ['hard_stop_rules', 'combination_rules', 'yellow_rules', 'numeric_rules'].flatMap((k) => m[k] || []));
const draftTotal = allRules.filter((r) => r.clinical_sign_off_pending || r.status === 'draft').length;

const css = `
  @page { size: A4; margin: 15mm 13mm 16mm 13mm; }
  * { box-sizing: border-box; }
  body { font-family:'Segoe UI','Nirmala UI','Noto Sans Bengali',sans-serif; color:#1c2333; font-size:10.2pt; line-height:1.45; margin:0; }
  code { font-family:'Cascadia Code','Consolas',monospace; font-size:8.6pt; background:#eef0fb; padding:1px 5px; border-radius:4px; color:#2c2f6b; }
  h1 { font-size:22pt; color:#312e81; margin:2px 0 4px; letter-spacing:-.5px; }
  h2 { font-size:14.5pt; color:#fff; background:#4f46e5; padding:7px 12px; border-radius:7px; margin:0 0 10px; }
  h3 { font-size:12pt; color:#312e81; margin:14px 0 6px; }
  .sub-lead { color:#475569; font-size:10pt; }
  .lbl { display:inline-block; font-size:7.4pt; font-weight:700; text-transform:uppercase; letter-spacing:.5px; color:#6366f1; margin-right:4px; }
  .cover { padding:10px 0 6px; border-bottom:3px solid #4f46e5; margin-bottom:16px; }
  .pills span { display:inline-block; background:#eef0fb; color:#312e81; border:1px solid #d6d8f5; border-radius:20px; padding:3px 11px; font-size:8.6pt; margin:2px 4px 2px 0; }
  .draft-banner { background:#fef3c7; border:1.5px solid #fcd34d; border-left:6px solid #d97706; border-radius:8px; padding:10px 14px; margin:10px 0 4px; font-size:9pt; color:#92400e; }
  .badge { display:inline-block; color:#fff; font-weight:700; font-size:8pt; padding:1px 8px; border-radius:20px; }
  .badge.red{background:#dc2626;} .badge.yellow{background:#d97706;} .badge.green{background:#16a34a;}
  .chip { display:inline-block; font-size:7.2pt; font-weight:700; padding:1px 7px; border-radius:20px; text-transform:uppercase; letter-spacing:.3px; }
  .chip.hard{ background:#fee2e2; color:#b91c1c; border:1px solid #fca5a5; } .chip.soft{ background:#f1f5f9; color:#475569; border:1px solid #cbd5e1; }
  .tag.draft { background:#ffedd5; color:#9a3412; border:1px solid #fdba74; font-size:7.2pt; font-weight:700; padding:1px 7px; border-radius:20px; text-transform:uppercase; }
  table { border-collapse:collapse; width:100%; margin:6px 0 12px; font-size:8.8pt; }
  th,td { border:1px solid #dadcef; padding:4px 7px; text-align:left; vertical-align:top; }
  thead th { background:#eef0fb; color:#312e81; }
  section.case { page-break-before: always; }
  .case-meta { display:flex; flex-wrap:wrap; gap:14px; font-size:9pt; color:#475569; margin-bottom:6px; }
  .draftc { color:#9a3412; }
  .rule { border:1px solid #e5e7f2; border-left-width:5px; border-radius:7px; padding:8px 11px; margin:0 0 9px; page-break-inside:avoid; background:#fcfcff; }
  .rule.red{border-left-color:#dc2626;} .rule.yellow{border-left-color:#d97706;} .rule.green{border-left-color:#16a34a;}
  .rule-head { display:flex; flex-wrap:wrap; align-items:center; gap:7px; margin-bottom:4px; }
  .rid { font-weight:800; font-size:10pt; color:#1e1b4b; font-family:'Cascadia Code','Consolas',monospace; }
  .refer { margin-left:auto; font-size:8.4pt; font-weight:700; color:#b91c1c; }
  .rule.yellow .refer{ color:#b45309; }
  .cond,.action,.action-bn,.sub { font-size:9pt; margin:2px 0; }
  .cond { color:#111827; } .and{ color:#6366f1; font-weight:700; font-size:8pt; }
  .action { background:#f8fafc; border-radius:5px; padding:3px 7px; }
  .action-bn { color:#334155; }
  .sub { color:#64748b; font-size:8.3pt; }
  .score { font-size:8.4pt; color:#64748b; margin-top:6px; }
  .foot { margin-top:20px; padding-top:8px; border-top:1px solid #e5e7eb; font-size:8pt; color:#94a3b8; }
`;

const html = `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<title>AshaMitra — Live Engine Rules ${esc(eng.version)}</title><style>${css}</style></head><body>
  <div class="cover">
    <h1>AshaMitra — Live Engine Rulebook</h1>
    <div class="sub-lead">The exact rules the app runs to decide 🟢 Green / 🟡 Yellow / 🔴 Red — generated from <code>asha_engine.json</code> for clinical sign-off.</div>
    <div class="pills">
      <span>Engine ${esc(eng.engine_id || '')}</span><span>Version ${esc(eng.version)}</span>
      <span>${eng.modules.length} modules</span><span>${allRules.length} rules</span>
      <span>Deterministic</span><span>Red-lock</span>
    </div>
    <div class="draft-banner"><b>⚠ ${draftTotal} rules are DRAFT (clinical_sign_off_pending).</b>
    They are live in the app but <b>not clinically validated</b> — each must be reviewed and approved by the
    AIIH&amp;PH / WB Health Secretariat clinical committee. Look for the <span class="tag draft">DRAFT · SIGN-OFF</span> tag.</div>
  </div>

  <section>
    <h3>How the engine decides</h3>
    <p class="sub-lead">Deterministic, offline, no LLM in the decision. Evaluation order:
    <b>${(eng.engine_rules && eng.engine_rules.evaluation_order || []).join(' → ')}</b>; first hard-stop locks
    <b>RED</b> (never downgraded); fallback <b>${eng.engine_rules && eng.engine_rules.fallback_band || 'GREEN'}</b>.</p>
    <h3>Answer model (graded)</h3>
    <table><thead><tr><th>Worker answer</th><th>Meaning</th><th>Effect</th></tr></thead><tbody>
      <tr><td>হ্যাঁ / yes</td><td>danger sign present</td><td>fires the rule (usually ${badge('RED')})</td></tr>
      <tr><td>খুব কম / অনেক / একবার (severe)</td><td>severe degree</td><td>fires the rule, same as yes</td></tr>
      <tr><td>মাঝে মাঝে / কিছুটা / একটু (mild)</td><td>intermittent / partial</td><td>at least ${badge('YELLOW')}</td></tr>
      <tr><td>না / no</td><td>absent</td><td>does not fire</td></tr>
      <tr><td>নিশ্চিত না / unsure</td><td>worker not certain</td><td><b>blocks GREEN</b> → at least ${badge('YELLOW')}</td></tr>
    </tbody></table>
    <h3>Patient-profile adaptive layer (escalation only — never downgrades)</h3>
    <p class="sub-lead">Using the beneficiary profile + prior visits: newborn &lt; 7 days and infant &lt; 3 months escalate any YELLOW → RED;
    maternal age &lt; 18 or &gt; 35, a prior RED outcome, or ≥ 2 missed ANC escalate GREEN → YELLOW. With no patient selected
    (urgent walk-in) the engine applies no profile escalation and the rule-based band stands.</p>
    <h3>Bands → referral</h3>
    <table><thead><tr><th>Band</th><th>Action</th><th>Referral</th></tr></thead><tbody>
    ${['GREEN', 'YELLOW', 'RED'].map((b) => { const x = (eng.bands || {})[b] || {}; return `<tr><td>${badge(b)}</td><td>${esc(x.action_en || '')}</td><td>${esc(x.referral || '')}</td></tr>`; }).join('')}
    </tbody></table>
  </section>

  ${eng.modules.map((m, i) => moduleSection(m, i + 1)).join('')}

  <div class="foot">Generated from asha_engine.json (engine ${esc(eng.version)}). Bands: 🟢 home care · 🟡 PHC within 24 h · 🔴 FRU/SNCU/DH immediately, call 108.
  A fired RED can never be downgraded. DRAFT rules await AIIH&amp;PH / Secretariat clinical sign-off.</div>
</body></html>`;

fs.writeFileSync(OUT, html, 'utf8');
console.log(`Wrote ${OUT} — engine ${eng.version}, ${eng.modules.length} modules, ${allRules.length} rules, ${draftTotal} draft.`);
