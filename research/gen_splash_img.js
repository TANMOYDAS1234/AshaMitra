/**
 * Generate a portrait splash image (tender mother + sleeping newborn) for the
 * splash screen. Writes ashamitra/assets/images/splash_mother.png.
 * Uses the paid GEMINI_API_KEY from ashamitra/backend/.env (never printed).
 *   node research/gen_splash_img.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const ENV = path.join(ROOT, 'ashamitra', 'backend', '.env');
const IMG = path.join(ROOT, 'ashamitra', 'assets', 'images');

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

const PROMPT =
  'A tender, beautiful photorealistic portrait: a young Indian mother in a soft ' +
  'cream and gentle-purple saree cradling her sleeping newborn baby wrapped in a ' +
  'white muslin cloth against her chest, her hand cradling the baby\'s head, eyes ' +
  'closed, a serene loving smile. Warm soft diffused light, calm dignified mood, ' +
  'intimate and hopeful. Smooth warm plum-tinted background with soft vignette so ' +
  'the top area is darker for overlay text. Vertical 9:16 full-frame portrait, ' +
  'subject in the lower-middle. No text, no logo, no watermark.';

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
          body: JSON.stringify({ contents: [{ parts }], generationConfig: cfg }) });
      if (!res.ok) { lastErr = `${model}: ${res.status} ${(await res.text()).slice(0, 140)}`; continue; }
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
  fs.mkdirSync(IMG, { recursive: true });
  const { b64, model } = await generate(KEY, [{ text: PROMPT }]);
  fs.writeFileSync(path.join(IMG, 'splash_mother.png'), Buffer.from(b64, 'base64'));
  console.log(`  OK splash_mother.png  (${model}, ${(b64.length / 1333).toFixed(0)} KB)`);
})();
