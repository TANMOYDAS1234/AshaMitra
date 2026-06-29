/**
 * Generate the missing "other" (general patient) module illustration in the
 * SAME flat-cartoon MCP-card style as the existing ones, conditioned on anc.png
 * for style consistency. Reads GEMINI_API_KEY from ashamitra/backend/.env
 * (never printed). Writes ashamitra/assets/illustrations/other.png.
 *   node research/gen_other.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const ENV = path.join(ROOT, 'ashamitra', 'backend', '.env');
const OUT = path.join(ROOT, 'ashamitra', 'assets', 'illustrations');

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

const STYLE =
  'Flat 2D vector cartoon illustration in the style of an Indian government ' +
  'NHM / MCP-card / UNICEF maternal-and-child-health education poster. Warm, ' +
  'friendly, simple rounded shapes, clean flat colours with soft shading. ' +
  'Rural Indian context; brown-skinned characters with gentle smiling faces. ' +
  'Single subject centered with generous margin, landscape 16:9 composition, ' +
  'soft pastel background. No text, no letters, no numbers, no watermark, no ' +
  'logo. Wholesome, clean, professional.';

const PROMPT =
  'Use the SAME flat-cartoon art style, colour palette and line weight as the ' +
  'previous image. A friendly Indian ASHA community health worker — a woman in ' +
  'a colourful sari with a bindi — smiling warmly and holding a health record ' +
  'card/clipboard, welcoming a patient for a general health check-up. Soft ' +
  'pale-amber background. ' + STYLE;

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

(async () => {
  const KEY = envKey();
  if (!KEY) { console.error('No GEMINI_API_KEY'); process.exit(1); }
  const ref = fs.readFileSync(path.join(OUT, 'anc.png')).toString('base64');
  const parts = [
    { inlineData: { mimeType: 'image/png', data: ref } },
    { text: PROMPT },
  ];
  let lastErr = '';
  for (const [model, cfg] of ATTEMPTS) {
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ contents: [{ parts }], generationConfig: cfg }),
        },
      );
      if (!res.ok) { lastErr = `${model}: ${res.status} ${(await res.text()).slice(0, 160)}`; continue; }
      const b64 = extractImage(await res.json());
      if (!b64) { lastErr = `${model}: no image part`; continue; }
      fs.mkdirSync(OUT, { recursive: true });
      fs.writeFileSync(path.join(OUT, 'other.png'), Buffer.from(b64, 'base64'));
      console.log(`  ✓ other.png  (${model}, ${(b64.length / 1333).toFixed(0)} KB)`);
      return;
    } catch (e) { lastErr = `${model}: ${e.message}`; }
  }
  console.error('  ✗ other.png:', lastErr);
  process.exit(1);
})();
