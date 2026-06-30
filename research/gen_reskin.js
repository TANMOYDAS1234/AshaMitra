/**
 * Reskin asset batch: regenerate module illustrations + per-trimester ANC art +
 * hero photo, in the new palette with the ASHA worker in a purple saree.
 * Illustrations are style-conditioned on research/samples/sample_module_anc.png
 * and photos on research/samples/sample_hero_asha.png for consistency.
 *   node research/gen_reskin.js
 * Uses the paid GEMINI_API_KEY from ashamitra/backend/.env (never printed).
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const ENV = path.join(ROOT, 'ashamitra', 'backend', '.env');
const ILLO = path.join(ROOT, 'ashamitra', 'assets', 'illustrations');
const IMG = path.join(ROOT, 'ashamitra', 'assets', 'images');
const SAMPLES = path.join(__dirname, 'samples');

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

const PALETTE =
  'App palette: primary purple #791C87, secondary magenta #BD3773, tertiary ' +
  'warm orange #FC8155, soft sage-green background #EAF3EC. ';

const ILLO_STYLE =
  'Flat 2D vector cartoon illustration, Indian NHM / MCP-card / UNICEF ' +
  'maternal-and-child-health poster style. Warm friendly simple rounded shapes, ' +
  'clean flat colours with soft shading, brown-skinned characters with gentle ' +
  'smiling faces, rural Indian context. Single subject centered, generous margin, ' +
  'square composition, soft sage-green background. ' + PALETTE +
  'No text, no letters, no numbers, no watermark, no logo. Wholesome, clean, professional.';

const PHOTO_STYLE =
  'Warm photorealistic documentary photograph, natural soft daylight, shallow ' +
  'depth of field, rural West Bengal village. Authentic, dignified, hopeful. ' + PALETTE;

const SAME = 'Use the SAME flat-cartoon art style, colour palette, line weight and sage-green background as the reference image. ';

// dst dir, filename, conditioning sample, prompt
const ITEMS = [
  // ── Module illustrations (overwrite) ──
  [ILLO, 'anc.png', 'sample_module_anc.png',
    `A happy pregnant Indian mother in a deep-purple and magenta sari with bindi, one hand on her round belly, smiling. ${SAME}${ILLO_STYLE}`],
  [ILLO, 'pnc.png', 'sample_module_anc.png',
    `A smiling Indian mother in a purple sari gently cradling her newborn baby wrapped in soft white cloth, looking down lovingly. ${SAME}${ILLO_STYLE}`],
  [ILLO, 'hbnc.png', 'sample_module_anc.png',
    `A cute newborn baby swaddled in a soft white cloth with a little cap, sleeping peacefully. ${SAME}${ILLO_STYLE}`],
  [ILLO, 'hbyc.png', 'sample_module_anc.png',
    `A happy Indian toddler about 1 to 2 years old standing and waving, chubby cheeks, big smile, simple purple-and-orange clothes. ${SAME}${ILLO_STYLE}`],
  [ILLO, 'vaccine.png', 'sample_module_anc.png',
    `A friendly non-scary vaccination scene: a cartoon vaccine vial and a syringe with a small smiling droplet, cheerful and reassuring, purple and magenta tones. ${SAME}${ILLO_STYLE}`],
  [ILLO, 'other.png', 'sample_module_anc.png',
    `A friendly Indian ASHA community health worker wearing a PURPLE saree, holding a clipboard and smiling warmly, welcoming gesture. ${SAME}${ILLO_STYLE}`],
  // ── Per-trimester ANC art (new) — pregnant figure, growing belly ──
  [ILLO, 'anc_t1.png', 'sample_module_anc.png',
    `A pregnant Indian mother in a purple sari, EARLY pregnancy with a small gentle belly bump, standing in profile, hand resting on belly, calm smile. ${SAME}${ILLO_STYLE}`],
  [ILLO, 'anc_t2.png', 'sample_module_anc.png',
    `A pregnant Indian mother in a purple sari, SECOND trimester with a clearly rounded medium belly, standing in profile, both hands cupping her belly, content smile. ${SAME}${ILLO_STYLE}`],
  [ILLO, 'anc_t3.png', 'sample_module_anc.png',
    `A pregnant Indian mother in a purple sari, THIRD trimester with a large full belly, standing in profile supporting her lower back with one hand, serene. ${SAME}${ILLO_STYLE}`],
  [ILLO, 'anc_t4.png', 'sample_module_anc.png',
    `A pregnant Indian mother in a purple sari, FULL TERM with a very large belly, standing in profile with a packed bag beside her ready for delivery, hopeful smile. ${SAME}${ILLO_STYLE}`],
  // ── Hero photo (new) ──
  [IMG, 'hero_asha.png', 'sample_hero_asha.png',
    `An Indian ASHA community health worker wearing a PURPLE saree, warmly talking with a smiling pregnant village woman, holding a small tablet, sitting together. Wide landscape 16:9 composition. ${PHOTO_STYLE}`],
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
  for (const [dir, file, sample, prompt] of ITEMS) {
    const parts = [];
    const sp = path.join(SAMPLES, sample);
    if (fs.existsSync(sp)) {
      parts.push({ inlineData: { mimeType: 'image/png', data: fs.readFileSync(sp).toString('base64') } });
    }
    parts.push({ text: prompt });
    try {
      const { b64, model } = await generate(KEY, parts);
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, file), Buffer.from(b64, 'base64'));
      console.log(`  OK ${file}  (${model}, ${(b64.length / 1333).toFixed(0)} KB)`);
    } catch (e) {
      console.error(`  FAIL ${file}: ${e.message}`);
    }
  }
  console.log('Done.');
})();
