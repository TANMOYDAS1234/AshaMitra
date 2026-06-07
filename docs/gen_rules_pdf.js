// Generates a print-ready HTML rulebook of the AshaMitra clinical decision
// engine, covering all 7 triage cases. Reads the two source-of-truth JSON
// files and merges them: triage_cases.json (the 7 cases, questions, options,
// Bengali action cards) + clinical_decision_engine.json (the formal decision
// rules: condition sets, logic, escalation rules, referral targets,
// classification). No external deps; absolute paths via fs so the empty
// ashamitra/package.json never enters module resolution.
//
//   node docs/gen_rules_pdf.js
//   -> writes docs/AshaMitra_Decision_Rules.html

const fs = require('fs');
const path = require('path');

const DATA = path.join(__dirname, '..', 'ashamitra', 'assets', 'data');
const TC = JSON.parse(fs.readFileSync(path.join(DATA, 'triage_cases.json'), 'utf8'));
const CDE = JSON.parse(fs.readFileSync(path.join(DATA, 'clinical_decision_engine.json'), 'utf8'));
const OUT = path.join(__dirname, 'AshaMitra_Decision_Rules.html');

// ---- merge: index every formal decision rule by ruleId --------------------
const ruleById = {};
for (const m of CDE.modules) {
  for (const r of m.decision_rules) ruleById[r.ruleId] = { ...r, _module: m.module_id };
}

// ---- small html helpers ---------------------------------------------------
const esc = (s) =>
  String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
const bandClass = (b) => ({ RED: 'red', YELLOW: 'yellow', GREEN: 'green' }[b] || 'green');
const badge = (b) => `<span class="badge ${bandClass(b)}">${esc(b)}</span>`;

// ---- render one rule card -------------------------------------------------
function ruleCard(q) {
  const r = ruleById[q.ruleId] || {};
  const band = q.risk || r.band || 'GREEN';
  const hardStop = q.hardStop || r.hard_stop;
  const referral = r.referral || (band === 'RED' ? 'FRU / SNCU / DH immediately'
    : band === 'YELLOW' ? 'PHC within 24 h' : 'Home care');
  const logic = r.logic || '';
  const options = (q.options || []).map(esc).join(' &nbsp;·&nbsp; ');
  const symptoms = (q.symptoms && q.symptoms.length ? q.symptoms
    : (r.symptoms_matched || [])).map(esc).join(' · ');
  const note = q.riskNote || r.risk_note || '';
  const action = q.action || r.action_en || '';
  const actionBn = r.action_bn || '';

  let esc_block = '';
  if (r.escalation_rule) {
    esc_block = `<div class="escalation"><span class="lbl">Escalation</span>
      <code>${esc(r.escalation_rule.logic)}</code> → ${badge(r.escalation_rule.band)}</div>`;
  }
  let signoff = '';
  if (q.clinicalSignOffPending || r.clinical_sign_off_pending) {
    signoff = `<div class="signoff">⚠ Clinical sign-off pending — ${esc(q.signOffNote || r.sign_off_note || '')}</div>`;
  }
  let invariant = '';
  if (r.invariant || q.invariant) {
    invariant = `<div class="invariant">🔒 Re-sweep invariant — ${esc(r.invariant_note || q.invariantNote || '')}</div>`;
  }

  return `
  <div class="rule ${bandClass(band)}">
    <div class="rule-head">
      <span class="rid">${esc(q.ruleId)}</span>
      ${badge(band)}
      ${hardStop ? '<span class="chip hardstop">HARD-STOP</span>' : '<span class="chip soft">scored</span>'}
      <span class="qid">${esc(q.id)}</span>
      ${r.priority ? `<span class="prio">priority ${r.priority}</span>` : ''}
      <span class="refer">→ ${esc(referral)}</span>
    </div>
    <div class="q-bn">${esc(q.text || q.text_bn || '')}</div>
    <div class="q-en">${esc(q.textEn || q.text_en || '')}</div>
    ${options ? `<div class="opts"><span class="lbl">Answers</span> ${options}</div>` : ''}
    ${logic ? `<div class="logic"><span class="lbl">Logic</span> <code>${esc(logic)}</code></div>` : ''}
    ${esc_block}
    ${note ? `<div class="note"><span class="lbl">Risk note</span> ${esc(note)}</div>` : ''}
    ${action ? `<div class="action"><span class="lbl">Action</span> ${esc(action)}</div>` : ''}
    ${actionBn ? `<div class="action-bn">${esc(actionBn)}</div>` : ''}
    ${symptoms ? `<div class="sym"><span class="lbl">Maps to symptoms</span> ${symptoms}</div>` : ''}
    ${signoff}${invariant}
  </div>`;
}

// ---- render one case section ----------------------------------------------
function caseSection(c, idx) {
  const counts = { RED: 0, YELLOW: 0, GREEN: 0 };
  for (const q of c.questions) counts[(q.risk || 'GREEN')]++;
  const rules = c.questions.map(ruleCard).join('\n');
  return `
  <section class="case">
    <h2>${esc(idx)}. ${esc(c.title)}</h2>
    <div class="case-meta">
      <span><b>${esc(c.titleEn)}</b></span>
      <span>Module: <code>${esc(c.module)}</code></span>
      <span>Protocol basis: <b>${esc(c.protocol)}</b></span>
      <span>Rules: ${c.questions.length}</span>
    </div>
    <div class="case-counts">
      ${badge('RED')} ${counts.RED} &nbsp; ${badge('YELLOW')} ${counts.YELLOW} &nbsp; ${badge('GREEN')} ${counts.GREEN}
    </div>
    <div class="kw"><span class="lbl">Detection keywords</span> ${(c.keywords || []).map(esc).join(' · ')}</div>
    ${rules}
  </section>`;
}

// ---- global engine rules + band resolution --------------------------------
const eng = CDE.engine_rules;
const engineSection = `
  <section class="engine">
    <h2>How the engine decides</h2>
    <p class="lead">The clinical engine is <b>deterministic</b> — the same answers always
    produce the same triage band, byte-for-byte. <b>No LLM sits in the diagnostic path.</b>
    Rules are evaluated top-to-bottom; the first hard-stop match exits immediately as RED.</p>
    <table class="eng">
      <tr><th>Hard-stop answer triggers</th><td>${eng.hard_stop_answer_triggers.map(esc).join(' · ')}</td></tr>
      <tr><th>Yellow answer triggers</th><td>${eng.yellow_answer_triggers.map(esc).join(' · ')}</td></tr>
      <tr><th>Evaluation order</th><td>${esc(eng.evaluation_order)}</td></tr>
      <tr><th>Multi-condition logic</th><td>${esc(eng.multi_condition_logic)}</td></tr>
      <tr><th>Band-lock rule</th><td>${esc(eng.band_lock_rule)}</td></tr>
      <tr><th>Fallback band</th><td>${badge(eng.fallback_band)} (when no rule fires)</td></tr>
    </table>

    <h3>Band resolution &amp; referral</h3>
    <table class="bands">
      <thead><tr><th>Rule</th><th>Band</th><th>Condition</th><th>Referral</th><th>Action</th></tr></thead>
      <tbody>
      ${CDE.band_resolution.map((b) => `<tr>
        <td><code>${esc(b.ruleId)}</code></td>
        <td>${badge(b.band)}</td>
        <td>${esc(b.condition)}</td>
        <td>${esc(b.referral)}</td>
        <td>${esc(b.action_en)}</td></tr>`).join('')}
      </tbody>
    </table>
  </section>`;

// ---- master rule index ----------------------------------------------------
function indexRows() {
  let rows = '';
  TC.cases.forEach((c, i) => {
    c.questions.forEach((q) => {
      const r = ruleById[q.ruleId] || {};
      const band = q.risk || r.band || 'GREEN';
      rows += `<tr>
        <td>${esc(c.titleEn)}</td>
        <td><code>${esc(q.ruleId)}</code></td>
        <td>${badge(band)}</td>
        <td>${(q.hardStop || r.hard_stop) ? 'Yes' : '—'}</td>
        <td>${esc((r.referral) || '')}</td></tr>`;
    });
  });
  return rows;
}

const allCases = TC.cases.map((c, i) => caseSection(c, i + 1)).join('\n');

const css = `
  @page { size: A4; margin: 16mm 14mm 18mm 14mm; }
  * { box-sizing: border-box; }
  body { font-family: 'Segoe UI','Nirmala UI','Noto Sans Bengali',sans-serif;
         color:#1c2333; font-size:10.3pt; line-height:1.45; margin:0; }
  code { font-family:'Cascadia Code','Consolas',monospace; font-size:9pt;
         background:#eef0fb; padding:1px 5px; border-radius:4px; color:#2c2f6b; }
  h1 { font-size:23pt; margin:0 0 4px; color:#312e81; letter-spacing:-.5px; }
  h2 { font-size:15pt; color:#fff; background:#4f46e5; padding:7px 12px;
       border-radius:7px; margin:0 0 10px; }
  h3 { font-size:12pt; color:#312e81; margin:16px 0 7px; }
  .lead { color:#374151; }
  .lbl { display:inline-block; font-size:7.6pt; font-weight:700; text-transform:uppercase;
         letter-spacing:.5px; color:#6366f1; margin-right:4px; }

  /* cover */
  .cover { padding:14px 0 6px; border-bottom:3px solid #4f46e5; margin-bottom:20px; }
  .cover .sub { font-size:12pt; color:#4b5563; margin:2px 0 10px; }
  .cover .pills span { display:inline-block; background:#eef0fb; color:#312e81;
        border:1px solid #d6d8f5; border-radius:20px; padding:3px 11px; font-size:8.6pt; margin:2px 4px 2px 0; }
  .meta-grid { margin-top:12px; font-size:9pt; color:#4b5563; }
  .meta-grid div { margin:2px 0; }

  /* badges + chips */
  .badge { display:inline-block; color:#fff; font-weight:700; font-size:8pt;
           padding:1px 8px; border-radius:20px; letter-spacing:.3px; }
  .badge.red{background:#dc2626;} .badge.yellow{background:#d97706;} .badge.green{background:#16a34a;}
  .chip { display:inline-block; font-size:7.4pt; font-weight:700; padding:1px 7px;
          border-radius:20px; text-transform:uppercase; letter-spacing:.4px; }
  .chip.hardstop{ background:#fee2e2; color:#b91c1c; border:1px solid #fca5a5; }
  .chip.soft{ background:#f1f5f9; color:#475569; border:1px solid #cbd5e1; }

  /* engine + tables */
  table { border-collapse:collapse; width:100%; margin:6px 0 14px; font-size:9pt; }
  th,td { border:1px solid #dadcef; padding:5px 8px; text-align:left; vertical-align:top; }
  thead th, table.eng th { background:#eef0fb; color:#312e81; }
  table.eng th { width:30%; }

  /* case */
  section.case { page-break-before: always; }
  .case-meta { display:flex; flex-wrap:wrap; gap:14px; font-size:9pt; color:#475569; margin-bottom:6px; }
  .case-counts { margin:4px 0 8px; }
  .kw { font-size:8.3pt; color:#64748b; margin-bottom:12px; }

  /* rule card */
  .rule { border:1px solid #e5e7f2; border-left-width:5px; border-radius:7px;
          padding:9px 12px; margin:0 0 10px; page-break-inside:avoid; background:#fcfcff; }
  .rule.red{ border-left-color:#dc2626; } .rule.yellow{ border-left-color:#d97706; }
  .rule.green{ border-left-color:#16a34a; }
  .rule-head { display:flex; flex-wrap:wrap; align-items:center; gap:7px; margin-bottom:5px; }
  .rid { font-weight:800; font-size:10.5pt; color:#1e1b4b; font-family:'Cascadia Code','Consolas',monospace; }
  .qid { font-size:8pt; color:#94a3b8; }
  .prio { font-size:8pt; color:#64748b; }
  .refer { margin-left:auto; font-size:8.6pt; font-weight:700; color:#b91c1c; }
  .rule.yellow .refer{ color:#b45309; } .rule.green .refer{ color:#15803d; }
  .q-bn { font-size:11pt; font-weight:600; color:#111827; }
  .q-en { font-size:9.4pt; color:#4b5563; font-style:italic; margin-bottom:4px; }
  .opts,.logic,.note,.action,.action-bn,.sym,.escalation { font-size:9pt; margin:3px 0; }
  .action { background:#f8fafc; border-radius:5px; padding:4px 7px; }
  .action-bn { color:#334155; }
  .note { color:#9a3412; }
  .escalation { color:#b91c1c; }
  .sym { color:#64748b; font-size:8.4pt; }
  .signoff { margin-top:5px; font-size:8.5pt; background:#fef3c7; border:1px solid #fde68a;
             color:#92400e; padding:4px 8px; border-radius:5px; }
  .invariant { margin-top:5px; font-size:8.5pt; background:#ede9fe; border:1px solid #ddd6fe;
               color:#5b21b6; padding:4px 8px; border-radius:5px; }
  .foot { margin-top:24px; padding-top:8px; border-top:1px solid #e5e7eb;
          font-size:8pt; color:#94a3b8; }
`;

const html = `<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<title>AshaMitra — Clinical Decision Rules</title>
<style>${css}</style></head>
<body>

  <div class="cover">
    <h1>AshaMitra — Clinical Decision Rules</h1>
    <div class="sub">Complete rulebook for all 7 triage cases — the exact logic the app uses to decide 🟢 Green / 🟡 Yellow / 🔴 Red</div>
    <div class="pills">
      <span>Engine: ${esc(CDE.engine_id)}</span>
      <span>Engine v${esc(CDE.version)}</span>
      <span>Cases dataset v${esc(TC.version)}</span>
      <span>Deterministic</span>
      <span>Offline-capable</span>
      <span>No LLM in diagnosis</span>
      <span>Re-sweep invariant</span>
    </div>
    <div class="meta-grid">
      <div><b>Protocol basis:</b> ${esc((CDE.protocol_basis || []).join(', '))}</div>
      <div><b>Cases:</b> ${TC.cases.map((c) => esc(c.titleEn)).join(' · ')}</div>
      <div><b>Source of truth:</b> assets/data/clinical_decision_engine.json + assets/data/triage_cases.json</div>
    </div>
  </div>

  ${engineSection}

  <h3 style="page-break-before:auto;">Reading a rule card</h3>
  <p style="font-size:9pt;color:#475569;margin-top:0;">Each rule below shows: its <b>ID</b>, the triage
  <b>band</b> it fires, whether it is a <b>HARD-STOP</b> (irreversible RED) or a <b>scored</b> sign, the
  <b>question</b> (Bengali + English) and answer options, the deterministic <b>logic</b>, any
  <b>escalation</b> to a higher band, the <b>action</b> the ASHA must take, and the <b>referral</b> target.</p>

  ${allCases}

  <section class="case">
    <h2>Master rule index</h2>
    <table class="bands">
      <thead><tr><th>Case</th><th>Rule ID</th><th>Band</th><th>Hard-stop</th><th>Referral target</th></tr></thead>
      <tbody>${indexRows()}</tbody>
    </table>
  </section>

  <div class="foot">
    Generated from the tracked rule files of the AshaMitra repository
    (clinical_decision_engine.json v${esc(CDE.version)} + triage_cases.json v${esc(TC.version)}).
    Bands: 🟢 Green = home care · 🟡 Yellow = PHC within 24 h · 🔴 Red = FRU/SNCU/DH immediately (≤ 30–60 min), call 108.
    A fired RED can never be downgraded. Items flagged "clinical sign-off pending" await AIIH&PH / Secretariat confirmation.
  </div>

</body></html>`;

fs.writeFileSync(OUT, html, 'utf8');
const rules = TC.cases.reduce((n, c) => n + c.questions.length, 0);
console.log(`Wrote ${OUT}`);
console.log(`Cases: ${TC.cases.length} · Rules rendered: ${rules}`);
