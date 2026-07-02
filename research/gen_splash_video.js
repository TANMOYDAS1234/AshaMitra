/**
 * Try to generate a short splash-screen video via Gemini Veo, poll the
 * long-running op, and download the mp4 to ashamitra/assets/video/splash.mp4.
 * Uses the paid GEMINI_API_KEY from ashamitra/backend/.env (never printed).
 *   node research/gen_splash_video.js
 * If Veo isn't enabled on the key, it prints the error so we fall back to a
 * pure-Flutter animated splash instead.
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const ENV = path.join(ROOT, 'ashamitra', 'backend', '.env');
const OUT = path.join(ROOT, 'ashamitra', 'assets', 'video');

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

const BASE = 'https://generativelanguage.googleapis.com/v1beta';
const MODELS = ['veo-3.0-fast-generate-001', 'veo-3.0-generate-001', 'veo-2.0-generate-001'];

const PROMPT =
  'A calm, premium splash-screen animation for a rural maternal-health mobile app. ' +
  'A softly glowing rounded orb in deep purple and magenta gently pulses like a ' +
  'heartbeat at the centre, with slow floating soft-magenta light particles and a ' +
  'smooth purple-to-magenta gradient background that subtly shifts. Warm, hopeful, ' +
  'minimal, elegant motion. Vertical 9:16. No text, no logos, no people.';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function start(KEY, model) {
  const res = await fetch(`${BASE}/models/${model}:predictLongRunning?key=${KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      instances: [{ prompt: PROMPT }],
      parameters: { aspectRatio: '9:16', personGeneration: 'dont_allow' },
    }),
  });
  const txt = await res.text();
  if (!res.ok) throw new Error(`${model}: ${res.status} ${txt.slice(0, 200)}`);
  return JSON.parse(txt).name; // operations/....
}

async function poll(KEY, opName) {
  for (let i = 0; i < 40; i++) {
    await sleep(8000);
    const res = await fetch(`${BASE}/${opName}?key=${KEY}`);
    const data = await res.json();
    if (data.error) throw new Error(`op error: ${JSON.stringify(data.error).slice(0, 200)}`);
    if (data.done) return data;
    process.stdout.write('.');
  }
  throw new Error('timed out waiting for video');
}

function findVideoUri(op) {
  const r = op.response || {};
  const cands = [
    r?.generateVideoResponse?.generatedSamples?.[0]?.video?.uri,
    r?.generatedVideos?.[0]?.video?.uri,
    r?.videos?.[0]?.uri,
  ];
  for (const u of cands) if (u) return u;
  // Fallback: deep-scan for any *.uri that looks like a file link.
  const seen = JSON.stringify(r);
  const m = seen.match(/"uri":"(https:[^"]+)"/);
  return m ? m[1] : null;
}

(async () => {
  const KEY = envKey();
  if (!KEY) { console.error('No GEMINI_API_KEY'); process.exit(1); }
  let lastErr = '';
  for (const model of MODELS) {
    try {
      console.log(`Trying ${model} ...`);
      const op = await start(KEY, model);
      console.log(`  op: ${op}  (polling, ~1-3 min)`);
      const done = await poll(KEY, op);
      const uri = findVideoUri(done);
      if (!uri) { lastErr = `${model}: no video uri in op response: ${JSON.stringify(done.response).slice(0,300)}`; continue; }
      const dl = await fetch(uri.includes('key=') ? uri : `${uri}${uri.includes('?') ? '&' : '?'}key=${KEY}`);
      if (!dl.ok) { lastErr = `${model}: download ${dl.status}`; continue; }
      const buf = Buffer.from(await dl.arrayBuffer());
      fs.mkdirSync(OUT, { recursive: true });
      fs.writeFileSync(path.join(OUT, 'splash.mp4'), buf);
      console.log(`\n  OK splash.mp4 (${model}, ${(buf.length / 1024 / 1024).toFixed(1)} MB)`);
      return;
    } catch (e) { lastErr = e.message; console.log(`\n  x ${e.message}`); }
  }
  console.error(`\nAll Veo attempts failed. Last: ${lastErr}`);
  process.exit(2);
})();
