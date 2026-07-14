# ASHAMitra — The 11-Step Decision Pipeline

> The on-device clinical "brain". Source: [`lib/core/services/rule_executor.dart`](../lib/core/services/rule_executor.dart) + [`lib/core/services/layers/`](../lib/core/services/layers/).
> Companion docs: [clinical modules](MODULES.md) · [sign-off rules](SIGNOFF_RULES.md) · [overview + backend](MODULES_REFERENCE.md).

The pipeline takes a patient's **answers + measured vitals** and runs them through **11 layers in a fixed order**, producing one `DecisionOutput`: the band (🟢/🟡/🔴), referral, action card, follow-up, and a full audit trace. It runs entirely **on the phone, offline**.

## 🟢 In easy words
Picture a **careful nurse taking the patient through 11 safety gates**, one after another. The answers + measurements go in one end; a clear decision (a colour + what to do) comes out the other.

1. **Form check** — is everything filled in properly?
2. **Sense check** — any impossible entry (like oxygen 105%)?
3. **Right checklist** — newborn form for a newborn, etc.
4. **Missing measurement?** — note what wasn't measured, and stay extra careful.
5. **Rulebook seal** — is the rulebook the real, untouched one?
6. **Main decision** — run the danger-sign rules → first colour.
7. **Danger score** — add up points for each problem.
8. **Background** — very new baby / risky-age mother / past red case → be stricter.
9. **Safety net** — one last double-check; bump up if anything still looks unsafe.
10. **Where + how fast** — which facility, how urgent, call 108?
11. **Final card** — show the worker the colour, the action, and the reason.

## The golden rule
> **The pipeline can only escalate, never downgrade.** Once any RED-tier rule fires, RED is *locked* — no later layer can lower it. For a frontline worker, over-warning is always safer than missing a real danger.

Layers **1–5** are gatekeepers (a blocking error here halts the pipeline with band `UNKNOWN` / `pipelineBlocked`). Layers **6–11** produce and refine the decision.

---

## Layer 1 — Input Validator
**File:** [`layers/input_validator.dart`](../lib/core/services/layers/input_validator.dart) · **Job:** make sure the form is usable before anything runs.

Blocks on: empty `moduleId`, unknown module, empty answers, a null/ wrong-typed answer (must be bool or string), a non-numeric or negative vital. Warns (non-blocking) on: empty `caseId`, a null vital (that vital's numeric rules are simply skipped).

## Layer 2 — Contradiction Checker
**File:** [`layers/contradiction_checker.dart`](../lib/core/services/layers/contradiction_checker.dart) · **Job:** catch impossible or self-contradicting input.

**Hard-blocks (physically impossible vitals):** SpO₂ > 100%, temp > 45 °C, respiratory rate > 120/min, systolic BP > 300, **diastolic ≥ systolic**. **Warns only (clinically odd but possible):** e.g. lethargy without poor feeding, cyanosis without breathing difficulty, severe dehydration without diarrhoea, bleeding with normal fetal movement.

## Layer 3 — Age / Module Validator
**File:** [`layers/age_module_validator.dart`](../lib/core/services/layers/age_module_validator.dart) · **Job:** right checklist for the right patient.

Age bounds: newborn **0–28 d**, child **61 d–5 y**, immunisation **0–16 y**; pregnancy & postpartum have no age bound but **require female sex** (male → block). Mismatch suggests the correct module. Warns if no age is given for an age-sensitive module.

## Layer 4 — Required Vital Checker
**File:** [`layers/required_vital_checker.dart`](../lib/core/services/layers/required_vital_checker.dart) · **Job:** note which critical vitals are missing.

Per module it knows the **RED-tier vitals** (e.g. newborn: SpO₂, RR, temp; pregnancy: systolic, diastolic, Hb; postpartum: temp, Hb). Missing ones **don't block** — they set `hasBlockingGaps`, which Layer 8 uses to escalate conservatively (you can't call a patient "safe" if you never measured the dangerous vital).

## Layer 5 — Protocol Hash Verify
**File:** [`layers/protocol_hash_verifier.dart`](../lib/core/services/layers/protocol_hash_verifier.dart) · **Job:** tamper seal on the rulebook.

Computes a SHA-256 of `asha_engine.json`. First load registers the hash; later loads compare against it — a mismatch within a session halts the pipeline (`HASH_001`). The hash is also written into the audit trace.

---

## Layer 6 — Rule Engine (the heart)
**File:** [`layers/rule_engine.dart`](../lib/core/services/layers/rule_engine.dart) · **Job:** run the module's rules and set the provisional band.

Four stages, in order:
1. **hard_stop** — any one matching answer → `redLock = true`, band RED.
2. **combination** — all conditions of a combo true → RED (locks) or YELLOW.
3. **numeric** — vital thresholds (only if vitals were given) → RED or YELLOW.
4. **yellow** — single smaller signs → YELLOW. **Skipped entirely once RED is locked.**

**Graded answers:** an answer of *"mild/intermittent"* or *"unsure"* on a danger sign forces at least YELLOW (never let an uncertain danger sign pass as GREEN). Also computes the raw risk score for the audit trail.
**Outputs:** `redLock`, `provisionalBand`, `triggeredRules`, suspected conditions, danger signs, `winningRule` (drives the action card), and a per-rule trace.

## Layer 7 — Severity Scoring
**File:** [`layers/severity_scoring_engine.dart`](../lib/core/services/layers/severity_scoring_engine.dart) · **Job:** a weighted danger score (advisory — never downgrades RED).

`total = answer-weights + vital-penalties`. Only the **highest penalty per vital** counts:

| Vital | Penalty ladder |
|---|---|
| SpO₂ | < 90 → +4 · < 95 → +2 |
| Respiratory rate | > 60 → +3 · > 50 → +2 |
| Temperature | > 40 → +3 · > 38.5 → +2 · > 37.5 → +1 |
| Systolic BP | ≥ 160 → +4 · ≥ 140 → +2 |
| Diastolic BP | ≥ 110 → +3 · ≥ 90 → +2 |
| Haemoglobin | < 7 → +4 · < 10 → +2 |
| MUAC | < 11.5 → +4 · < 12.5 → +2 |

The total maps to a score-band via the module's thresholds and a risk level (LOW / MODERATE / HIGH / CRITICAL).

## Layer 8 — Adaptive Risk
**File:** [`layers/adaptive_risk_engine.dart`](../lib/core/services/layers/adaptive_risk_engine.dart) · **Job:** raise the band based on context. **Never downgrades RED** (returns immediately if `redLock`).

| Trigger | Effect | Code |
|---|---|---|
| Newborn < 7 days | YELLOW → RED | ADAPT_D_001 |
| Newborn weight < 2 kg | GREEN → YELLOW | ADAPT_D_002 |
| Infant < 3 months (child module) | YELLOW → RED | ADAPT_D_003 |
| Pregnancy age < 18 or > 35 | GREEN → YELLOW | ADAPT_D_004 |
| Any prior RED outcome | GREEN → YELLOW | ADAPT_H_001 |
| High-Risk-Pregnancy flag | GREEN → YELLOW | ADAPT_H_002 |
| ≥ 2 missed ANC visits | GREEN → YELLOW | ADAPT_H_003 |
| Last visit RED < 48 h ago | YELLOW → RED | ADAPT_H_004 |
| RED-tier vital missing | GREEN → YELLOW | ADAPT_V_001 |
| RED-tier vital missing | YELLOW → RED | ADAPT_V_002 |
| Score-band RED | YELLOW → RED | ADAPT_S_001 |
| Score-band YELLOW | GREEN → YELLOW | ADAPT_S_002 |

## Layer 9 — Safety Escalation
**File:** [`layers/safety_escalation_layer.dart`](../lib/core/services/layers/safety_escalation_layer.dart) · **Job:** final safety net (5 checks).

1. **Sign-off-pending note** — if a fired rule is draft, attach a `SAFETY_A_001` advisory (no band change). See [SIGNOFF_RULES.md](SIGNOFF_RULES.md).
2. **Emergency cross-sweep** — re-run the **emergency** module's hard-stops against the answers even in a non-emergency module; any hit → RED.
3. **RED-lock floor** — if `redLock` was set but band somehow isn't RED, force RED.
4. **Referral sanity** — if band is RED but referral is blank, default to "FRU / SNCU / DH immediately".
5. **GREEN-with-danger-signs** — if band is GREEN yet danger signs exist, bump to YELLOW.

## Layer 10 — Referral Decision
**File:** [`layers/referral_decision_engine.dart`](../lib/core/services/layers/referral_decision_engine.dart) · **Job:** where to send, how fast, follow-up.

| Band | Urgency | Max delay | Transport |
|---|---|---|---|
| 🔴 RED | Immediate | 30 min | "Call 108 now" (or "keep stable" if already called) |
| 🟡 YELLOW | Within 24 hours | 1440 min | Arrange transport (+ distance estimate) |
| 🟢 GREEN | Routine | 0 | None |

Facility depends on module+band (e.g. newborn-RED → SNCU/FRU; pregnancy-GREEN → routine ANC at PHC). Travel time is estimated at 30 km/h rural road speed. Follow-up: RED-refused recheck in 4 h, YELLOW in 24 h.

## Layer 11 — Explainable Output
**File:** [`layers/explainable_output.dart`](../lib/core/services/layers/explainable_output.dart) · **Job:** assemble the final answer the worker sees.

Builds the bilingual (Bengali + English) **action card** ("🔴 জরুরি …" / "🟡 সতর্কতা …" / "🟢 স্বাভাবিক …") plus referral, suspected conditions, danger signs, severity breakdown, adaptive adjustments, safety flags, missing vitals, the protocol hash, and the full rule-by-rule trace — so any case can be replayed/audited later.

---

## Supporting services
- **[`vitals_extractor.dart`](../lib/core/services/vitals_extractor.dart)** — pulls BP, temperature (auto-converts °F→°C when value > 45), MUAC, SpO₂, weight, respiratory rate, and haemoglobin out of free speech; normalises Bengali digits; and can speak an immediate danger alert.
- **[`offline_brain.dart`](../lib/core/services/offline_brain.dart)** — chooses the next most-urgent question to ask (priority: hard-stop 100 > combination 60 > yellow 30 > base 10, with a +60 boost if answering it would complete a RED combination) and fires combination/single-sign alerts; ends the session at 3+ confirmed danger signs.

## One worked example
Newborn, worker enters *"fever 37.8°C"*, baby is 5 days old:
1. L1–L5 pass. 2. **L6** — `NB-002` (any newborn fever) and `NB-VITAL-003` (≥37.5 °C) both fire → **RED locked**. 3. **L8** — newborn < 7 days, but it's already RED, so unchanged. 4. **L10** — SNCU/FRU, immediate, "call 108". 5. **L11** — red card: *"🔴 জরুরি — এখনই SNCU-তে রেফার করুন।"*
