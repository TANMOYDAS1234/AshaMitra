# Production Setup — External Steps

The code is production-ready. Two manual setup tasks remain that can
only be done with your own accounts.

---

## 1. UptimeRobot keep-warm (5 min, free) — **OR** GitHub Actions

### Option A: GitHub Actions (already wired)

A workflow at `.github/workflows/keep-render-warm.yml` pings the backend
every 10 minutes from GitHub's free Actions runners. To enable it:

1. Push this workflow file to the `TANMOYDAS1234/AshaMitra` repo.
   (If your PAT lacks the `workflow` scope you'll need to either
   upgrade the PAT scope or commit the file via the GitHub web UI:
   *Add file → Create new file → name it
   `.github/workflows/keep-render-warm.yml`, paste contents, commit.*)
2. The schedule activates within ~30 min of the first push. Check
   the **Actions** tab on GitHub to see it firing.
3. After it runs once, the Render service stops sleeping. Cold-start
   feel goes away.

### Option B: UptimeRobot (alternative, no GitHub workflow needed)

1. Sign up at https://uptimerobot.com (free tier covers 50 monitors).
2. Dashboard → **+ Add New Monitor**:
   - Monitor Type: **HTTP(s)**
   - Friendly Name: `AshaMitra warmup`
   - URL: `https://ashamitra-backend.onrender.com/health`
   - Monitoring Interval: **5 minutes**
3. **Create Monitor**. The first ping should land within seconds.

Either option works. Pick one — running both is harmless but wasteful.

---

## 2. Add more Gemini API keys (10 min, free) — fixes "AI at capacity"

The server now scans every env var matching `GEMINI_API_KEY_*` at
startup, so adding capacity is just an env-var change. Each free
Google AI Studio account gives 1,500 requests/day.

### Steps

1. Open https://aistudio.google.com in an incognito window.
2. Sign in with a Google account.
3. Top-left, click **Get API key** → **Create API key** → pick the
   default project → copy the key (starts with `AIza...`).
4. **Sign out**, switch to a different Google account, repeat. Aim
   for at least 5 keys total (yours + family + co-workers if any
   are willing).
5. Open the Render dashboard → your `ashamitra-backend` service →
   **Environment** tab.
6. You should already see `GEMINI_API_KEY`, `GEMINI_API_KEY_2`,
   `GEMINI_API_KEY_3`. Click **Add Environment Variable**, name it
   `GEMINI_API_KEY_4`, paste a new key, save. Repeat with `_5`,
   `_6`, etc.
7. Render auto-restarts the service after saving env vars. Check the
   logs — you should see `[Gemini] loaded N key(s)` where N is your
   new total.

### What this gives you

| # keys | Daily requests |
|--------|---------------:|
| 3 (current) | 4,500 |
| 5 | 7,500 |
| 8 | 12,000 |
| 12 | 18,000 |

For a 50-ASHA pilot doing ~10 cases/day, **8 keys is comfortable**.
The new per-key dead-marking logic also stops wasting requests on
already-exhausted keys, so the effective throughput is closer to the
theoretical max than before.

---

## (Optional) 3. Try a different voice

The default is now `bn-IN-Wavenet-A` (distinctly Indian Bengali).
If pilots prefer a different voice:

1. Render → Environment → set `GOOGLE_TTS_VOICE` to one of:
   - `bn-IN-Chirp3-HD-Aoede` — warm female, HD-smooth, neutral accent
   - `bn-IN-Chirp3-HD-Kore` — mature female, slightly Bangladeshi-lean
   - `bn-IN-Chirp3-HD-Leda` — soft female, higher pitch
   - `bn-IN-Wavenet-B` — male
2. Save → service restarts → next TTS call uses the new voice.

Note that the on-device + bundled MP3 cache is keyed to one voice
per build of the app. Swapping the env var means new phrases get
the new voice, but existing cached MP3s keep playing in the old one
until they're evicted. To force a clean reset, ping me to bump the
`_voice` tag in `vapi_tts_service.dart` and rebuild the APK.

---

## (Optional) 4. Groq paid tier — most stable LLM

For sustained high-load production, **Groq paid plan ($10/month)** is
the most reliable single change you can make. Sign up at
https://console.groq.com, upgrade, and the existing `GROQ_API_KEY`
env var in Render starts billing against the paid quota
(~10× the free throughput, much more stable rate limiting). Gemini
keys stay as the fallback.
