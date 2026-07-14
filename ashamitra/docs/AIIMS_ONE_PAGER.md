# ASHAMitra — One-Page Summary · AIIMS Kalyani

**An offline-first, Bengali-first digital workspace for ASHA workers — built around a clinical rulebook *your committee owns*.**
It replaces 15+ paper registers with one app on the ASHA's own phone. The clinical core is a **deterministic, guideline-sourced rule engine — not a black-box AI** — turning answers + vitals into a referral band: 🟢 home care · 🟡 refer PHC ≤24 h · 🔴 refer FRU/SNCU/DH now (call 108).

### Why a clinician can trust it
- **You own the rulebook.** Every decision is a readable rule citing a published guideline; the app **refuses to load rules your committee hasn't signed off.**
- **No generative AI in diagnosis.** LLMs only do Bengali voice/scribe + a general Q&A helper; the **deterministic engine makes every band decision.** Offline mode uses zero AI.
- **Reproducible & auditable.** Same input → same output; a SHA-256 protocol-hash proves which rule version decided any past case (MDSR-ready).
- **Sensitivity-first by design.** It over-refers on purpose — a missed neonatal sepsis is irreversible; a false alarm is a recoverable cost.

### The seven modules
🍼 Newborn (0–28 d) · 🧒 Child (2 mo–5 y) · 🤰 Pregnancy/ANC · 🤱 Postpartum (0–42 d) · 💉 Immunisation (UIP) · 👶 Development · 🚨 Emergency.
**Sources:** IMNCI · HBNC · HBYC · PMSMA HRP · WHO ANC 2016 · UIP — *each rule cites its source.*
**Engine v2.6.0:** 68 questions · 42 hard-stop · 19 combination · 24 yellow · 42 numeric rules · **64 rules awaiting your sign-off.**

### How it helps
Visit notes ~30 min → ~5 min (voice + structured) · monthly HMIS report auto-generated · high-risk-pregnancy score at every ANC visit · referral outcomes tracked — closing the community-to-facility "black box" · daily immunisation-defaulter list · SAM/MAM caught at the village.

### Data & security
Passwordless **phone OTP → role-scoped signed token** · **TLS** in transit · **PII stays on-device**, only de-identified data syncs · server-side API keys · pilot only after **AIIMS IEC clearance**, **DPDP Act 2023**-aligned.

### What we ask of AIIMS Kalyani
1. **Review** the 7 MVP modules against IMNCI / HBNC / HBYC / PMSMA / WHO ANC — tell us what to change.
2. **Sign off** clinical rules before they go live (no rule reaches the field without committee approval).
3. **Oversee** a 4–6 month pilot (~20 ASHAs, 1 district near Kalyani): monthly review + open emergency-consult channel.
4. **Guide** Phase-2 priorities (TB · NCD · mental health · MUAC · RKSK) and the Phase-3 diabetic-retinopathy hand-off.

> *Honest note: it is a screening / decision-support tool, not a diagnostic device; the over-referral rate will be measured during the pilot; production hardening (at-rest DB encryption, enforced real-SMS OTP) completes before scale — under your oversight.*

**Flint De Orient Marketing & Technology Pvt Ltd** (DPIIT-recognised startup) · **Sabir Ali Mollah, Founder** · Kolkata
*Companion documents available: clinical modules & rules · the 11-step decision pipeline · the 64 sign-off rules · full clinical & technical briefing.*
