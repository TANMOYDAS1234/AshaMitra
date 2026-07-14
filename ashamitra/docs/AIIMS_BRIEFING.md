# ASHAMitra — Clinical & Technical Briefing for AIIMS Kalyani

> A talking-document for explaining ASHAMitra to clinicians: the logic, the modules, the rules, how it helps, **why we built it this way and not another**, and the backend / data-security choices — with the reasoning a doctor will want behind each one.
> Companion detail: [MODULES.md](MODULES.md) (every rule) · [PIPELINE.md](PIPELINE.md) (the decision engine) · [SIGNOFF_RULES.md](SIGNOFF_RULES.md) (rules awaiting your sign-off).

---

## 1. The 30-second statement
> *"ASHAMitra is an offline-first, Bengali-first digital workspace for ASHA workers. Its clinical core is a **deterministic, guideline-sourced rule engine** — not a black-box AI. Every danger-sign decision is reproducible, traceable to a published guideline, and only goes live after your committee signs it off. We are not asking you to trust an algorithm's judgement; we are asking you to **own the rulebook** it executes."*

This one line answers the doctor's first worry — *"is this another unaccountable AI?"* — with **no**.

---

## 2. The clinical logic — and why this logic, not another

### What the logic is
The triage decision is made by a **deterministic rule engine**: a fixed set of `IF condition THEN band` rules stored in a single file (`asha_engine.json`). Same inputs → same output, every time, on every phone. The output is a **band**: 🟢 GREEN (home care), 🟡 YELLOW (refer PHC ≤24 h), 🔴 RED (refer FRU/SNCU/DH now).

### Why deterministic rules — and explicitly **NO generative AI / LLM / ML model — in the diagnostic path**
This is the single most important design decision, so we made it on purpose:

| Property | Deterministic rules (what we use) | An AI / ML / LLM model (what we avoid for diagnosis) |
|---|---|---|
| **Reproducibility** | Identical input always gives identical output | Output can vary run to run |
| **Explainability** | Every decision lists the exact rule + guideline that fired | "Black box" — cannot always say *why* |
| **Auditability** | The exact rule version is reproducible months later (protocol hash) | Hard to reconstruct what a model did at a past moment |
| **Hallucination risk** | Impossible — it cannot invent a rule | LLMs can fabricate plausible-but-wrong advice |
| **Certification / sign-off** | A clinician can read and approve every rule | You cannot "read and approve" millions of model weights |
| **Data needed** | The published guideline | Large, locally-validated, labelled datasets we don't have |
| **Liability** | Decision is attributable to a signed guideline rule | Decision attributable to an opaque model — a governance problem |

**The clinician-facing summary:** *we deliberately traded "cleverness" for **accountability**.* At the village screening tier, an auditable, conservative rulebook a doctor can certify is worth more than a smarter system a doctor cannot certify.

> **Where AI *is* used (and why it's safe):** large-language models (Gemini/Groq) are used **only** as a (a) **voice/scribe layer** — turning the ASHA's free Bengali speech into structured yes/no answers — and (b) a **general Q&A helper** ("how do I make ORS?"). The **classification and band are always computed by the deterministic engine**, never by the LLM. The LLM is the *interpreter*; the rule engine is the *decision-maker*. An offline path uses rules only, with no AI at all.

---

## 3. The decision engine — what *guarantees* safety (in clinical terms)
The engine runs an **11-layer pipeline** ([PIPELINE.md](PIPELINE.md)) with safety properties a clinician will recognise:

- **Sensitivity-first (deliberate over-triage).** At a screening tier, missing a true danger sign (false negative) can be fatal; a false alarm (false positive) costs one referral. The risks are asymmetric, so the engine is tuned to **favour sensitivity over specificity**. We would rather over-refer than miss.
- **RED-lock — decisions only escalate, never downgrade.** Once any RED-tier rule fires, no later step can lower the band. There is no code path that turns a danger sign into "safe."
- **Universal danger-sign pre-sweep + emergency cross-sweep.** Before any module's specific questions, a danger-sign scan runs; and the emergency module's hard-stops are re-checked against *every* case — so a life-threatening sign is caught even if the worker picked the "wrong" module.
- **Conservative on missing data.** If a RED-tier vital was never measured, the engine cannot call the patient safe: it pushes GREEN→YELLOW and YELLOW→RED.
- **Graded uncertainty.** "Mild/intermittent" or "unsure" answers are never treated as GREEN — they force at least YELLOW.
- **Adaptive risk context.** A <7-day newborn, a <18/>35-year mother, prior RED outcomes, or ≥2 missed ANC visits raise the band — encoding the "high-risk patient" intuition explicitly.
- **Tamper-evidence.** Every case stores a SHA-256 **protocol hash** of the rulebook used, so the exact logic is reproducible for an MDSR/audit review.

---

## 4. The modules and rules — what's in the rulebook
**Seven modules** (full rules in [MODULES.md](MODULES.md)):

| Module | Population | Clinical basis |
|---|---|---|
| 🍼 Newborn | 0–28 days | HBNC + IMNCI · PSBI · jaundice · feeding |
| 🧒 Child | 2 mo–5 y | IMNCI + HBYC |
| 🤰 Pregnancy (ANC) | pregnant | PMSMA HRP + WHO ANC 2016 (dual-track: hard-stop + cumulative risk score) |
| 🤱 Postpartum (PNC) | 0–42 days | PPH (pad-soak proxy) · eclampsia · sepsis |
| 💉 Immunisation | birth–16 y | UIP schedule + catch-up |
| 👶 Development | 2 mo–3 y | MCP-card milestones |
| 🚨 Emergency | any | Cross-cutting danger-sign sweep |

**Rule shapes (five kinds):** *hard-stop* (one sign → RED), *combination* (signs together → band), *numeric* (a vital crossing a threshold), *yellow* (one smaller worry → YELLOW), and a weighted *risk score*.

**Engine totals (v2.6.0):** 7 modules · **68 questions · 42 hard-stop · 19 combination · 24 yellow · 42 numeric rules**. **64 rules are flagged `clinical_sign_off_pending`** — live, but explicitly **awaiting your committee's approval** ([SIGNOFF_RULES.md](SIGNOFF_RULES.md) lists each with an example scenario).

**Where the rules come from — and why that matters to you:** every rule is **transcribed from a published source you already trust** — IMNCI, HBNC, HBYC, PMSMA, UIP, WHO ANC 2016 — and each rule **cites its source**. We did not invent medicine; we encoded the protocols ASHAs are *already mandated* to follow. Your review is therefore a *verification* task, not a *creation* task.

**The sign-off gate (the trust mechanism):** *no clinical rule reaches production without committee approval, and the app refuses to load an unsigned rule bundle.* You hold the pen on the rulebook; we hold the software around it.

---

## 5. How it helps — workflow and health, concretely

**For the ASHA (less work, not more):**
| Task | Today (paper) | With ASHAMitra |
|---|---|---|
| Visit documentation | ~30 min, re-copied at night | ~5 min, voice + structured, saved as she works |
| Monthly HMIS report | ~2 evenings compiling registers | auto-generated from visits, ~10-min review |
| High-risk pregnancy | memory / register flags; often late | risk score every ANC visit + danger-sweep |
| Referral follow-up | refers and waits; outcome rarely returns | cascade tracked; alert on non-arrival |

**For the village (earlier, reliable catching):** newborn PSBI/jaundice/feeding problems caught **at the visit** not at the mortality audit; high-risk pregnancies flagged from the first ANC contact; daily immunisation-defaulter list; SAM/MAM caught at the village not the quarterly review; and — uniquely — the **community-to-facility referral link** (today a black box) becomes visible, surfacing *why* referrals fail (transport, cost, distance, mistrust) while it's still actionable, and supporting MDSR review.

---

## 6. "Why this way and not another?" — the design-choice FAQ
The questions a careful doctor will ask, with our answers:

**Q. Why not use AI/ML to make it smarter?**
Because at this tier *accountability beats cleverness*. We cannot certify, reproduce, or audit a model's judgement — and you cannot sign it off. A rulebook you can read, approve, and reproduce is the safer, defensible choice. (See §2.)

**Q. Why digitise the *whole* workflow instead of just a triage app?**
Because partial digitisation is **worse than paper**: it forces the ASHA to run app *and* paper in parallel — two systems, double the work, trust in neither. Field experience showed this clearly. Making paper genuinely redundant is what earns adoption and data integrity.

**Q. Why offline-first / on-device?**
Rural connectivity is unreliable and a danger-sign decision cannot wait for a server. The full rule engine runs **on the phone**, so triage works in a hut with no signal. The internet is used only for sync and the optional voice helper.

**Q. Why over-triage — won't false alarms overload facilities?**
A screening tool's job is **sensitivity**. A missed neonatal sepsis is irreversible; a false referral is a recoverable cost. We bias toward safety *on purpose*, and the referral-tracking data lets us measure and tune the false-positive rate during the pilot with your oversight.

**Q. Why run it on a cheap phone, not give ASHAs tablets?**
It must work on the **entry-level Android she already owns** — no hardware barrier, no procurement dependency, immediate scalability.

**Q. Why Bengali-first with voice?**
Because the user is a Bengali-speaking community worker, often more fluent speaking than typing. Voice + touch + her language = lower error, faster capture, real adoption.

---

## 7. Backend technology — and why
- **Node.js + Express + MongoDB (Atlas → now self-managed VPS).** *Why:* the data is naturally document-shaped (patient records, rule bundles, reports as JSON), MongoDB stores it without translation, and Node lets the same JSON flow end to end. The VPS removes cold-start delays for rural latency.
- **The clinical engine is NOT on the backend.** *Why:* keeping triage on-device guarantees offline operation and means the server can never be a single point of clinical failure. The backend handles records, scheduling, reporting, sync, and the optional voice/AI helper — never the band decision.
- **AI helper isolation.** Gemini/Groq calls go **through the backend**, never the app, so API keys live server-side and cannot be extracted from the APK; responses are cached; and this path is strictly the conversational/voice layer (§2), not diagnosis.
- **Auto-generated HMIS + MCH scheduling + reminder engine.** *Why:* the report is a by-product of work already done (no double entry), and ANC/vaccine/HBNC schedules are derived deterministically from LMP/DOB so nothing depends on memory.

---

## 8. Data, authentication & security — and why
**Authentication: passwordless phone OTP → signed token.**
- The ASHA logs in with a **one-time password sent to her registered phone**; the server then issues a **signed JWT** (JSON Web Token, 30-day), **role-scoped** to `asha_worker` or `admin`. Every API call carries this token; the server verifies it on every request.
- *Why OTP, not passwords:* ASHAs have phones, not password managers — OTP is low-friction, nothing to forget, tied to one device. *Why JWT:* a standard, stateless, tamper-evident token that carries the user's role so the server can enforce who-can-do-what (e.g. admin-only endpoints).
- The token is held in the phone's **OS-encrypted secure storage** (Android Keystore), not in plain app storage.

**Data handling & privacy:**
- **PII stays on the device first** (offline-first capture); sync is controlled. *Why:* the village keeps the names; the goal is that only **de-identified** data leaves the phone for research/policy.
- **Transport encryption:** all app↔backend and backend↔database traffic is over **HTTPS/TLS**. *Why:* nothing clinical travels in the clear.
- **Server-side secrets:** all third-party API keys are server-side only.
- **Designed toward DPDP Act 2023** (India's data-protection law) and **gated behind AIIMS IEC clearance** — *no pilot data collection begins until the ethics committee approves.*

---

## 9. What we are **NOT** claiming (so we stay credible)
State these plainly — doctors trust a team that names its limits:
- The engine is a **screening / decision-support tool**, **not a diagnostic device** and not a replacement for clinical judgement. It tells the ASHA *when to refer*, not a final diagnosis.
- It is **deliberately over-sensitive**; the false-positive (over-referral) rate is a thing we will **measure with you** during the pilot, not a solved number.
- **64 rules await your sign-off** — they are live but flagged as draft; we want them validated, not rubber-stamped.
- **Production hardening still to complete before scale:** at-rest encryption of the full on-device record store (e.g. SQLCipher), real-SMS OTP enforced in production (pilot mode currently eases login for testing), and a strong production token secret. We will close these before any wider rollout, under your oversight.

---

## 10. Likely questions from the committee — quick answers
- **"Who is accountable for a wrong decision?"** → The rule is attributable to a *signed, sourced guideline*; the protocol hash proves which version ran. Accountability sits with the approved rulebook, which you control — not a hidden model.
- **"Can it work without internet?"** → Yes — the full triage engine is on-device.
- **"What if the AI mis-hears a vital?"** → The AI only structures speech; the worker confirms, the deterministic engine decides, and impossible values are rejected by a contradiction check. Offline mode uses no AI at all.
- **"How do we change a rule we disagree with?"** → It's one line in a human-readable file; you approve the change, we re-sign the bundle, the app picks up the new (hashed) version. Nothing is hard-coded in a binary.
- **"How is patient privacy protected?"** → PII stays on-device; only de-identified data is intended to sync; transport is TLS; access is OTP+role-scoped JWT; the pilot runs under IEC clearance and DPDP.

---

### One-paragraph close for the meeting
> *"Everything clinical in ASHAMitra is a rule you can read, a source you can check, and a decision you can reproduce. We've put your committee at the centre — the app literally refuses to run rules you haven't signed. We're not asking you to trust our software's judgement; we're asking you to own the medical logic, and let us handle the engineering that delivers it, offline and in Bengali, into the ASHA's hands."*
