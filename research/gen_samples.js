/**
 * Generate 2 STYLE-SAMPLE images for the reskin (so the look can be approved
 * before regenerating the whole asset set). Writes to research/samples/.
 * Uses the paid GEMINI_API_KEY from ashamitra/backend/.env (never printed).
 *   node research/gen_samples.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const ENV = path.join(ROOT, 'ashamitra', 'backend', '.env');
const OUT = path.join(__dirname, 'samples');

function envKey() {
  const txt = fs.readFileSync(ENV, 'utf8');
  let paid = null, any = null;
  for (const line of txt.split(/\r?\n/)) {
    const m = line.match(/^\s*(GEMINI_API_KEY(?:_\d+)?)\s*=\s*(.+)\s*$/);
    if (!m) continue;
    const v = m[2].replace(/^["']|["']$/g, '').trim();
    if (!v) continue;
    if (m[1] === 'GEMINI_API_KEY') paid = v;
    any ??= v;
  }
  return paid || any;
}

// New-palette art direction.
const PALETTE =
  'App brand palette: primary purple #791C87, secondary magenta #BD3773, ' +
  'tertiary warm orange #FC8155, soft sage-green background #EAF3EC. ';

const ILLO_STYLE =
  'Flat 2D vector cartoon illustration, Indian government NHM / MCP-card / ' +
  'UNICEF maternal-and-child-health education poster style. Warm friendly simple ' +
  'rounded shapes, clean flat colours with soft shading, brown-skinned characters ' +
  'with gentle smiling faces, rural Indian context. Single subject centered with ' +
  'generous margin, landscape 16:9, soft sage-green background. ' + PALETTE +
  'No text, no letters, no numbers, no watermark, no logo. Wholesome, clean, professional.';

const PHOTO_STYLE =
  'Warm photorealistic documentary photograph, natural soft daylight, shallow ' +
  'depth of field, rural West Bengal village courtyard. Authentic, dignified, ' +
  'hopeful mood. ' + PALETTE;

const ITEMS = [
  {
    f: 'sample_module_anc.png',
    p: `A happy pregnant Indian mother in a deep-purple and magenta sari with a bindi, ` +
       `smiling, one hand resting gently on her round belly. ${ILLO_STYLE}`,
  },
  {
    f: 'sample_hero_asha.png',
    p: `An Indian ASHA community health worker wearing a PURPLE saree, sitting on a ` +
       `woven mat and warmly talking with a pregnant village woman, holding a small ` +
       `tablet. Both smiling. ${PHOTO_STYLE}`,
  },
];

const ATTEMPTS = [
  ['gemini-2.5-flash-image', { responseModalities: ['IMAGE'] }],
  ['gemini-2.5-flash-image-preview', { responseModalities: ['IMAGE'] }],
  ['gemini-2.0-flash-preview-image-generation', { responseModalities: ['TEXT', 'IMAGE'] }],
];

function extractImage(data) {
  const parts = data?.candidates?.[0]?.content?.parts || [];
  for (const p of parts) {
    const d = p.inlineData?.data || p.inline_data?.data;
    if (d) return d;
  }
  return null;
}

async function generate(KEY, parts) {
  let lastErr = '';
  for (const [model, cfg] of ATTEMPTS) {
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${KEY}`,
        { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ contents: [{ parts }], generationConfig: cfg }) },
      );
      if (!res.ok) { lastErr = `${model}: ${res.status} ${(await res.text()).slice(0, 160)}`; continue; }
      const b64 = extractImage(await res.json());
      if (!b64) { lastErr = `${model}: no image part`; continue; }
      return { b64, model };
    } catch (e) { lastErr = `${model}: ${e.message}`; }
  }
  throw new Error(lastErr || 'all models failed');
}

(async () => {
  const KEY = envKey();
  if (!KEY) { console.error('No GEMINI_API_KEY'); process.exit(1); }
  fs.mkdirSync(OUT, { recursive: true });
  for (const it of ITEMS) {
    try {
      const { b64, model } = await generate(KEY, [{ text: it.p }]);
      fs.writeFileSync(path.join(OUT, it.f), Buffer.from(b64, 'base64'));
      console.log(`  OK ${it.f}  (${model}, ${(b64.length / 1333).toFixed(0)} KB)`);
    } catch (e) {
      console.error(`  FAIL ${it.f}: ${e.message}`);
    }
  }
  console.log('Done. -> research/samples/');
})();
