# ASHAMitra — Research Report
### Overview · Literature Review · Gaps · Problem Statement · Solutions · Conclusion

> **Citation integrity note.** Every statistic in this report is traced to a primary source, cited inline. Where a widely-circulated figure could not be verified, it has been **deliberately excluded** and the reason recorded in §8. Nothing here is estimated or inferred without being labelled as such.

---

## 1. Overview of ASHAMitra

**ASHAMitra is an offline-first, Bengali-first digital workspace for ASHA (Accredited Social Health Activist) workers, built around a deterministic clinical decision-support engine that a medical committee owns and signs off.**

It replaces the ASHA's paper registers with a single application on her own entry-level Android phone, and — critically — it does not merely *collect* data for the government. It *returns clinical judgement to the worker at the point of care*.

**The clinical core.** Answers to simple questions plus measured vitals are evaluated by a deterministic rule engine (`asha_engine.json`, v2.6.0) that outputs a triage band:

| Band | Meaning | Action |
|---|---|---|
| 🟢 GREEN | No danger sign | Home care, routine follow-up |
| 🟡 YELLOW | Warning sign | Refer to PHC within 24 h |
| 🔴 RED | Danger sign | Refer FRU/SNCU/DH immediately (ambulance 108) |

**Engine composition (v2.6.0):** 7 clinical modules · 68 questions · 42 hard-stop rules · 19 combination rules · 24 yellow rules · 42 numeric (vital-threshold) rules. 64 rules are explicitly flagged `clinical_sign_off_pending` — live but awaiting formal clinician validation.

**The seven modules:** Newborn (0–28 d, PSBI/HBNC/IMNCI) · Child (2 mo–5 y, IMNCI/HBYC) · Pregnancy/ANC (PMSMA HRP + WHO ANC 2016) · Postpartum (0–42 d, PPH/eclampsia/sepsis) · Immunisation (UIP schedule) · Child Development (MCP-card milestones) · Emergency (cross-cutting danger-sign sweep).

**The decision pipeline (11 layers)** enforces properties that matter clinically: input validation → contradiction checking → age/module validation → missing-vital detection → protocol-hash (tamper) verification → rule evaluation → severity scoring → adaptive risk → safety escalation → referral decision → explainable output. Its governing invariants are:

- **Deterministic.** Identical inputs always produce identical outputs. No generative AI participates in classification.
- **RED-locks.** Once a danger-sign rule fires, no later layer can downgrade the band. The engine can only *escalate*.
- **Sensitivity-first.** It deliberately over-refers: a missed neonatal sepsis is irreversible; a false alarm is a recoverable cost.
- **Conservative on missing data.** An unmeasured RED-tier vital pushes GREEN→YELLOW and YELLOW→RED.
- **Auditable.** Each case stores a SHA-256 hash of the exact rulebook version used, reproducible months later for MDSR audit.

**Supporting features:** Bengali voice input/output; Aadhaar QR/OCR auto-fill; automatic MCH scheduling (ANC/immunisation/HBNC/HBYC derived from LMP/DOB); SMS + WhatsApp reminders to mothers; auto-generated monthly HMIS reporting; referral cascade tracking (destination, acceptance/refusal, refusal reason, outcome); one-tap Mother & Child Protection (MCP) card PDF; and full offline operation of the triage engine.

---

## 2. Literature Review

### 2.1 The global evidence base is weaker than commonly assumed
A systematic review and meta-analysis of mHealth for maternal and newborn health in low- and middle-income countries concluded that **"the available evidence is weak"** and results were **"too inconsistent to enable robust conclusions"** on health outcomes; only **2 of 12** intervention studies were at low risk of bias, and only one (Tanzania) demonstrated a mortality effect (Sondaal et al., *PLOS ONE*; https://pmc.ncbi.nlm.nih.gov/articles/PMC4643860/).

An India-specific review of the high-burden ("BIMARU") states found only **8 studies** met inclusion criteria and concluded that *"more studies utilising rigorous methodologies, such as true RCTs, are required"* (https://pmc.ncbi.nlm.nih.gov/articles/PMC10836675/).

### 2.2 The World Health Organization has already prescribed the correct architecture
This is the single most important citation in this report.

WHO's *Guideline: Recommendations on Digital Interventions for Health System Strengthening* (2019) makes two recommendations that bear directly on ASHAMitra's design:

- **Recommendation 7** — WHO **recommends health-worker decision support via mobile devices** for community- and facility-based health workers, where the tasks lie within the worker's defined scope of practice.
- **Recommendation 8** — WHO **recommends digital tracking of clients' health status *combined with* decision support**, conditional on the health system implementing **both components integrally**, and explicitly warns that **isolated implementation risks ineffectiveness**.

Source: https://www.ncbi.nlm.nih.gov/books/NBK541888/ (executive summary); https://www.ncbi.nlm.nih.gov/books/NBK541902/ (full guideline).

**India's national digital-health tools implement the tracking half and omit the decision-support half.** ANMOL, the Poshan Tracker, the RCH portal and HMIS are registration and reporting systems. None provides clinical decision support. This is not an opinion — it is a description, and WHO has already told us what it costs.

### 2.3 What India has built — and what the evidence actually shows

| Programme | Design of evidence | Process / coverage effect | Clinical outcome |
|---|---|---|---|
| **ImTeCHO** (Gujarat, ASHA job aid) | Cluster RCT, 22 PHCs, 5,754 births | ✅ MNCH coverage **+4.9 pp** (p=0.03); ≥2 first-week home visits **+10.2 pp** | ❌ **No mortality effect** (233 vs 236 infant deaths) |
| **ICT-CCS** (Bihar, CARE India) | Cluster RCT, 70 sub-centres | ✅ first-week postnatal visits 72% vs 60%; skin-to-skin **+13 pp**; immediate breastfeeding **+12 pp** | ❌ No effect on facility delivery, immunisation, exclusive breastfeeding |
| **ReMiND** (UP, CommCare, *has decision support*) | Quasi-experimental DiD | ✅ **complication identification +13.2% (pregnancy), +19.5% (postpartum)**; care-seeking **+25.7%**; IFA **+12.7%** | ⚠️ Mortality **modelled, not measured** |
| **Kilkari** (national IVR to mothers, 10M subscribers) | Individually randomised RCT (MP) | — | ❌ **Null on primary outcome** (exclusive breastfeeding, RR 1.04, CI 0.88–1.23) |
| **Khushi Baby** (Rajasthan, NFC + app) | Cluster RCT, Udaipur | process/engagement ✅ | ❌ **Null** — "did not directly result in an increase in infant immunization timeliness through DTP3" |
| **mMitra** (ARMMAN, Mumbai) | *Pseudo*-randomised | ✅ knowledge/practices | ⚠️ birth-weight "trend" only |
| **ICDS-CAS / Poshan** (Anganwadi) | Quasi-experimental (MP, Bihar) | ✅ home visits **+8 pp**; counselling recall **+11.5 pp** | ❌ **No effect on infant/young-child feeding practices**; **no improvement in actual ration receipt** |
| **ANMOL** (national, ANM tablet) | **No impact evaluation found** | — | — |
| **Poshan Tracker** (national) | **No peer-reviewed impact evaluation found** | — | — |
| **E-IMNCI** (Jharkhand, *deterministic CDSS*) | Pre-post pilot, 70 ANMs | ✅ respiratory-rate assessment **18% → 100%**; umbilical sepsis check **9% → 100%**; consultation time **24 → 12 min** | Not measured (small pilot, facility-based ANMs — **not ASHAs**) |

**Sources:** ImTeCHO — Modi et al., *PLOS Medicine* 2019, https://journals.plos.org/plosmedicine/article?id=10.1371%2Fjournal.pmed.1002939 · TECHO+ scale-up — *Frontiers in Public Health* 2022, https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2022.856561/full · ICT-CCS — https://pmc.ncbi.nlm.nih.gov/articles/PMC6875677/ · ReMiND — Prinja et al., *Cost Eff Resour Alloc* 2018, https://pmc.ncbi.nlm.nih.gov/articles/PMC6020234/ · Kilkari RCT — Mohan et al., *BMJ Global Health* 2022, https://pmc.ncbi.nlm.nih.gov/articles/PMC9288869/ · Kilkari reach — https://pmc.ncbi.nlm.nih.gov/articles/PMC9366343/ · Khushi Baby — Nagar et al., *Vaccine* 2018, https://pubmed.ncbi.nlm.nih.gov/29162321/ · mMitra — https://pmc.ncbi.nlm.nih.gov/articles/PMC7268375/ · ICDS-CAS — Avula et al., *BMJ Global Health* 2022, https://pmc.ncbi.nlm.nih.gov/articles/PMC9296874/ · ANMOL qualitative — *Indian J Community Med* 2026;51(2):358–365, https://journals.lww.com/ijcm/fulltext/2026/03000/perception_and_experiences_of_auxiliary_nurse.21.aspx · E-IMNCI — https://pmc.ncbi.nlm.nih.gov/articles/PMC10603548/

### 2.4 The pattern that emerges from the evidence
Three findings recur with unusual consistency across independent trials:

1. **Digital tools move what the worker directly controls** (home visits, counselling delivery, checklist adherence) **and fail to move what the system controls** (facility delivery, ration receipt, immunisation completion, mortality). The ImTeCHO, ICT-CCS and ICDS-CAS authors each state a version of this independently.
2. **The single function with outsized effect is decision support.** ReMiND — the only Indian ASHA tool with explicit decision support and referral algorithms — produced its largest gains in *complication identification* (+13.2% / +19.5%), not in routine coverage. E-IMNCI raised respiratory-rate assessment from 18% to 100%. Data-collection-only apps produce nothing comparable.
3. **The failures are not technological; they are failures of design intent.** Double data entry, surveillance framing, uncompensated workload, and data that flows upward but never back down are all symptoms of systems built to *report on* the ASHA rather than to *serve* her.

### 2.5 The documented burden on the ASHA — why any new app must *replace*, not *add*

- **More than ten registers, one per incentive category.** *"In most places, an individual ASHA maintains **more than ten different registers**… each register typically corresponding to a specific category of incentives."* One Maharashtra ASHA: *"**The entry of a single name has to be done in five registers.**"* Supervisors conceded the paperwork *"limited the time available for providing essential health services."* (Furtado et al., *Health Policy and Planning* 2025;40(4):483–495, https://academic.oup.com/heapol/article/40/4/483/8015911)
- **41 minutes per day on register maintenance** — roughly equal to *all* her MCH activity time (42 min/day), out of a 4.29 h working day. (Khandre et al., *Med J Armed Forces India* 2022, https://pmc.ncbi.nlm.nih.gov/articles/PMC10746798/)
- **The ASHA diary itself is unusable by design** — a usability study with 57 ASHAs found poor visual cues, difficulty of comprehension, inconsistent data presentation and excessive cognitive load. (Patel & Tandon, *Social Science & Medicine* 2025, https://www.sciencedirect.com/science/article/abs/pii/S0277953625007014)
- **Digitisation has so far *doubled* the burden, not removed it.** In Haryana, app proliferation plus poor connectivity *"forced many workers to maintain paper records in addition to the digital ones"* — doubling workload without compensation (https://www.ideasforindia.in/topics/productivity-innovation/is-digitalisation-a-double-edged-sword-for-workers-in-indias-public-healthcare-system). One ASHA reported juggling **seven apps** plus WhatsApp groups and spreadsheets, alongside four paper diaries: ***"Now we do everything twice — once online, and again on paper."*** (New Lines Magazine, https://newlinesmag.com/reportage/indias-digital-health-push-is-overworking-its-front-line-women/)
- **Apps that surveil get rejected.** Haryana's MDM360 Shield location-tracking app was perceived as surveillance and **recalled after collective action by ASHAs**. In Maharashtra, the *Hajeri* photo-attendance app was **discontinued after ASHA protests** (https://behanbox.com/2025/04/06/why-a-photo-backed-attendance-app-is-distressing-maharashtras-asha-workers/).

### 2.6 West Bengal — the specific landscape

**West Bengal has largely solved access. It has not solved continuity and quality of care.** The state's own numbers make this unusually clear.

| Indicator | **West Bengal** | **India** | Reading |
|---|---|---|---|
| Institutional births | **92%** | 89% | ✅ Access solved |
| Full basic immunisation (12–23 mo) | **88%** | 77% | ✅ Strong |
| Infant mortality rate (NFHS-5) | **22.0** | 35 | ✅ Well below national |
| Neonatal mortality rate (NFHS-5) | **15.5** | 25 | ✅ Well below national |
| Mothers with 4+ ANC visits | **76%** *(fell from 77%)* | 59% *(rose)* | ⚠️ High but **regressing** |
| IFA taken 180+ days | **31%** | — | 🔴 Very weak |
| **Anaemia, pregnant women** | **62.3%** | **52.2%** | 🔴 **Much worse than India** |
| Anaemia, all women 15–49 | **71%** *(up 9 pp)* | 57% | 🔴 Worsening sharply |
| Anaemia, children 6–59 mo | **69%** *(up 15 pp)* | 67% | 🔴 Worsening sharply |
| Stunting (<5 y) | **34%** *(rose from 33%)* | 36% | 🔴 Stuck / worsening |
| **Maternal Mortality Ratio (SRS 2018–20)** | **103** | **97** | 🔴 **Above national** |
| **MMR (SRS 2019–21)** | **109**\* | **93** | 🔴 **RISING while India falls** |

Sources: NFHS-5 West Bengal, IIPS & ICF 2021, https://dhsprogram.com/pubs/pdf/FR374/FR374_WestBengal.pdf · NFHS-5 India Vol. I, https://dhsprogram.com/pubs/pdf/FR375/FR375.pdf · SRS MMR Bulletin 2018–20, https://censusindia.gov.in/nada/index.php/catalog/44379/download/48052/SRS_MMR_Bulletin_2018_2020.pdf · SRS MMR Bulletin 2019–21, https://censusindia.gov.in/nada/index.php/catalog/45561/download/49758/SRS_MMR_Bulletin_2019_2021.pdf
\* *The 2019–21 WB MMR figure was extracted from the official SRS table; a visual confirmation of the source page is recommended before using it as a headline number.*

**The West Bengal paradox, stated plainly:** a woman in West Bengal is *more likely* than the average Indian woman to deliver in an institution (92%), to complete her immunisation schedule, and to see her baby survive infancy — **yet she is more likely to die in childbirth, and far more likely to be anaemic while pregnant.** Maternal mortality is *rising* here while it falls nationally.

High institutional delivery has not translated into falling maternal deaths. This is a **failure of antenatal continuity, risk detection and follow-up — not a failure of infrastructure.** It is precisely the failure a decision-support tool in the ASHA's hand is designed to address. NFHS-5's own conclusion on nutrition: *"Children's nutritional status in West Bengal has hardly changed since NFHS-4 by all measures."*

**And West Bengal has no ASHA-facing digital tool.**
- **65,743 ASHAs** work in West Bengal (NHSRC, https://nhsrcindia.org/asha-map-table).
- **Swasthya Sathi**, the flagship state health scheme, is **health insurance** (₹5 lakh/family/yr, 1,500+ empanelled hospitals). Its app is **beneficiary-facing only** — card status, hospital finder, grievances. It gives an ASHA **no work tool whatsoever** (https://swasthyasathi.gov.in/KeyFunctionality).
- **Swasthya Ingit**, the state telemedicine platform, was evaluated in Budge Budge-II block: **beneficiary satisfaction only 55.8%**, with CHOs reporting doctor unavailability, portal faults, *"fixed daily patient targets compromising care quality"* and *"internet speed is one huge problem in the village"* (Dutta et al., *Indian J Community Med* 2025;50(2):361–367, https://pmc.ncbi.nlm.nih.gov/articles/PMC12080889/).
- An exhaustive search of `wbhealth.gov.in`, WB NHM, Google Play and news media found **no West Bengal state-level application built for ASHAs or ANMs.** *(Stated as "no evidence found," not as proof of non-existence.)*

**The language gap is real and documented.** Bengali — the world's **seventh-largest** language group with **270 million speakers** — *"remains one of the most underserved populations in digital healthcare,"* and is a **low-resource language** in the digital domain with *"a pronounced lack of medical-specific foundational models."* Critically for design: *"the lack of standardization [of Bengali keyboards] makes typing Bengali in digital media unpopular among low socioeconomic groups and those with poor digital literacy"* — a direct argument for **voice-first Bengali input**. (Nahar et al., arXiv preprint 2510.24724, https://arxiv.org/pdf/2510.24724 — *preprint, not peer-reviewed; Bangladesh-authored; cited for its language-gap framing only.*)

**Finally, the political reality.** West Bengal's ASHAs went on **indefinite cease-work from 23 December 2025**, marching on Swasthya Bhawan in January 2026. Among their demands: **"exclusion from work unrelated to maternal and child health support"** (ThePrint, https://theprint.in/india/unhappy-with-pay-hike-asha-workers-protest-outside-bengal-health-department-hq/2847628/). Any tool that adds work will be rejected. Only a tool that *removes* work can be adopted.

---

## 3. The Gaps

Synthesising the literature, seven gaps are defensible and evidence-backed:

| # | Gap | Evidence |
|---|---|---|
| **G1** | **Tracking without decision support.** India's national tools (ANMOL, Poshan Tracker, RCH/HMIS) collect data; none supports a clinical decision. | WHO Rec. 8 explicitly warns isolated tracking "risks ineffectiveness" (NBK541888) |
| **G2** | **No deterministic, guideline-cited IMNCI/HBNC decision support in an ASHA's hand at scale.** The only India CDSS evidence (E-IMNCI) is a small pilot for *facility-based ANMs*. | PMC10603548 |
| **G3** | **The tools with the best evidence are black-box or non-clinical.** No comparator offers rules a clinical committee can read, approve and audit. | §2.3; MAATR uses "AI/ML predictive analytics" — unsignable by a committee |
| **G4** | **Digitisation has doubled the ASHA's burden rather than removing it.** Parallel paper persists; surveillance apps get withdrawn. | Ideas for India; New Lines; Behanbox; Furtado 2025 |
| **G5** | **Referral loop closure is missing — in the systems *and* in the literature.** e-Sanjeevani's own evaluators call it *"a critical gap"*; no Indian MNCH referral-completion evaluation appears to exist. | https://pmc.ncbi.nlm.nih.gov/articles/PMC12558045/ |
| **G6** | **No evidence base at national scale.** India's two largest FLW systems have *zero* published impact evaluations; every rigorous RCT was null on its clinical endpoint. | §2.3 |
| **G7** | **West Bengal specifically: rising MMR, worst-in-class pregnancy anaemia, regressing ANC — and no ASHA-facing digital tool, in a language digital health has neglected.** | §2.6 |

---

## 4. How ASHAMitra Fills Each Gap

| Gap | ASHAMitra's response |
|---|---|
| **G1** Tracking without CDSS | The engine is **decision support *combined with* tracking** — exactly WHO Recommendation 8. The band, referral and action card are produced at the point of care, and the same encounter feeds the record. |
| **G2** No deterministic CDSS for ASHAs | 7 modules · 68 questions · 127 rules encoding **IMNCI, HBNC, HBYC, PMSMA and WHO ANC 2016**, running **in the ASHA's hand, at the household, fully offline**. This is the empty cell in the literature. |
| **G3** Black-box logic | **Deterministic by construction.** No generative AI in the diagnostic path. Every rule is human-readable, cites its guideline source, and is gated behind a **clinical committee sign-off** — the app *refuses to load an unsigned rule bundle*. Each case carries a **SHA-256 protocol hash** so the exact logic is reproducible for MDSR audit. |
| **G4** Doubled burden | **Whole-workflow digitisation** — auto-generated HMIS reporting, auto-generated MCP card, auto-derived MCH schedules — so paper becomes genuinely redundant rather than parallel. Voice capture cuts visit documentation from ~30 min to ~5 min. Explicitly **not** a surveillance tool. |
| **G5** Open referral loop | A **referral cascade layer**: decision timestamp, GPS, recommended facility level, acceptance **or refusal**, **refusal reason** (transport/distance/cost/family/mistrust), facility outcome, and time-to-care. This directly instruments the gap e-Sanjeevani's evaluators named. |
| **G6** No evidence | An **AIIMS-supervised pilot with a pre-specified evaluation design** (≈20 ASHAs, 4–6 months, monthly clinical review, sub-sample case re-review) — deliberately building the evidence the field lacks, rather than scaling ahead of it. |
| **G7** West Bengal | **Bengali-first, voice-first** (addressing the documented Bengali typing/digital-literacy barrier); **haemoglobin thresholds and anaemia rules built into the ANC and PNC modules** (Hb <7 → RED; 7–10 → YELLOW), targeting the state's worst indicator; risk scoring at **every** ANC contact, targeting the regressing 4+ ANC and rising MMR. |

---

## 5. Problem Statement

> **In West Bengal, 65,743 ASHA workers carry the maternal and child health system on more than ten paper registers. They spend ~41 minutes a day maintaining those registers — as much time as they spend on all maternal and child health activity combined — and a danger sign recorded in a notebook remains invisible to anyone who could act on it until the monthly reporting day.**
>
> **The consequences are measurable. West Bengal achieves 92% institutional delivery, yet its maternal mortality ratio is *above* the national average and *rising* (103 → 109) while India's falls (97 → 93). 62.3% of pregnant women are anaemic, against 52.2% nationally. Four-or-more ANC visits are *declining*. Access has been solved; continuity, risk detection and follow-up have not.**
>
> **Existing digital health tools do not close this gap — and several have made it worse. India's national systems (ANMOL, Poshan Tracker, RCH/HMIS) collect data for the government but offer the ASHA no clinical decision support, contrary to WHO's explicit recommendation that tracking and decision support be implemented as an integral pair. Every rigorous Indian trial of a frontline-worker app has been null on its clinical endpoint. Digitisation has, in practice, forced ASHAs to "do everything twice — once online, and again on paper," and surveillance-flavoured apps have been withdrawn after worker protest. West Bengal has no ASHA-facing digital tool at all, in a language that digital health has systematically neglected.**
>
> **The gap is therefore precise: there exists no deterministic, guideline-sourced, clinically-auditable decision-support system, in Bengali, running offline in an ASHA's hand, that replaces her paperwork rather than adding to it, and that closes the referral loop.**

---

## 6. Solutions

ASHAMitra's design is a direct, point-by-point response to that problem statement.

**6.1 Put a clinical decision, not a data form, in her hand.**
A deterministic 11-layer engine converts her observations into an unambiguous action — 🟢 home care, 🟡 PHC within 24 h, 🔴 refer now — at the moment of the visit. This is the function the evidence says works (ReMiND: complication identification +13.2%/+19.5%; E-IMNCI: 18%→100% adherence) and the function India's national tools omit.

**6.2 Make the logic something a doctor can own.**
Rules are transcribed — not invented — from IMNCI, HBNC, HBYC, PMSMA, UIP and WHO ANC 2016, each citing its source. A **clinical sign-off gate** means no rule reaches the field without committee approval, and the app refuses unsigned bundles. A **protocol hash** on every case makes the decision reproducible for audit. This converts the reviewer's task from *"trust this algorithm"* to *"approve this rulebook"* — and it is what distinguishes ASHAMitra from AI/ML-based comparators that no committee can certify.

**6.3 Remove work; never add it.**
The monthly HMIS report is generated from visits already performed. The MCP card prints filled. ANC, immunisation, HBNC and HBYC schedules are derived automatically from LMP/DOB. Voice-first Bengali capture cuts documentation from ~30 to ~5 minutes. **Paper must become redundant, not parallel** — this is the single most important lesson from the Haryana and Maharashtra failures.

**6.4 Work where the network does not.**
The full rule engine runs **on-device**. Triage functions with no signal, in a hut, at night. Connectivity is required only for sync and the optional voice helper.

**6.5 Close the referral loop.**
Every referral records destination, acceptance/refusal, refusal reason, facility outcome and time-to-care — instrumenting the "critical gap" that e-Sanjeevani's own evaluators identified and that no Indian MNCH study has yet measured.

**6.6 Target West Bengal's actual failures.**
Haemoglobin thresholds (Hb <7 g/dL → RED; 7–10 → YELLOW) in both ANC and PNC modules attack the state's 62.3% pregnancy-anaemia rate. A risk score at *every* ANC contact attacks the regressing ANC coverage and rising MMR. Automatic reminders by SMS and WhatsApp attack default and discontinuity.

**6.7 Build the evidence, do not assume it.**
The field's defining pathology is scaling ahead of evidence. ASHAMitra proposes the opposite sequence: **clinical review → committee sign-off → IEC clearance → a supervised pilot with pre-specified outcomes → only then, scale.**

---

## 7. Conclusion

The literature supports an uncomfortable but clarifying conclusion: **India has built more digital health infrastructure for frontline workers than almost any country on earth, and generated less evidence of clinical benefit than almost any.** Its two largest national systems have never been evaluated. Every rigorous randomised trial — ImTeCHO, Kilkari, Khushi Baby, ICT-CCS — returned null on its clinical endpoint. And in the field, digitisation has too often *doubled* the ASHA's workload rather than lifting it, producing worker protest and app withdrawal.

Yet the same literature points, with unusual consistency, at what *does* work. The interventions that moved clinical needles were the ones that gave the worker **decision support** — the identification of a complication, the adherence to a clinical step — and not merely a data form. WHO has already codified this: tracking and decision support must be implemented **as an integral pair**, and tracking alone *"risks ineffectiveness."* India's national tools implement exactly the half WHO warned about.

West Bengal makes the case urgent and concrete. The state has solved access — 92% institutional delivery, immunisation above the national average, infant and neonatal mortality well below it. And yet **maternal mortality is rising there while it falls across India**, pregnancy anaemia stands at 62.3% against a national 52.2%, and antenatal coverage is *slipping*. These are not infrastructure failures. They are failures of **continuity, risk detection and follow-up** — carried, today, on more than ten paper registers by 65,743 women who have no digital tool of their own, in a language digital health has largely ignored, and who are on strike asking to be relieved of work unrelated to maternal and child health.

**ASHAMitra occupies the precise white space the evidence identifies:** a deterministic, guideline-sourced, committee-signed, offline, Bengali-first clinical decision-support system that replaces paperwork rather than adding to it, and that closes the referral loop. Its central claim is deliberately modest and therefore defensible — **not that an algorithm knows better than a clinician, but that a rulebook a clinician owns, executed faithfully at every household visit, will catch what a paper register currently hides.**

The remaining task is the one the field has consistently skipped: **to prove it.** That is what the proposed AIIMS Kalyani pilot — clinical review, committee sign-off, ethics clearance, then supervised deployment with pre-specified outcomes — is for.

---

## 8. Excluded claims (citation integrity)

The following widely-circulated figures were **deliberately excluded** because they could not be verified, or because they misrepresent their source. They are recorded here so that no reader reintroduces them.

1. **"ImTeCHO reduced infant mortality by 16% (IMR 56.4 vs 67.2)."** This comes from the *per-protocol* analysis in the **cost-effectiveness** paper, **not** the trial's intention-to-treat result. **The primary RCT found no mortality effect** (233 vs 236 infant deaths). Citing the 16% figure without this caveat misrepresents the evidence.
2. **"CommCare/Mathematica RCT: +73% ANC visits, +58% iron tablets, +36% contraception."** Not present on Dimagi's own evidence page; no peer-reviewed source located. **Do not cite.**
3. **"ASHAs maintain 15 registers."** The defensible, peer-reviewed claim is **"more than ten"** (Furtado et al. 2025).
4. **"40–65% of referrals go untracked."** This figure originates from a **US commercial vendor blog about American social-care referrals.** It is not an Indian health statistic.
5. **Khushi Baby / CHIP scale figures** (≈70,000 ASHAs, 40–46 M beneficiaries) are **organisation-reported**, with no independent evaluation of CHIP at state scale.
6. **West Bengal low birth weight rate** and **WB state-wise NMR from SRS** — **not found**; not estimated.
7. **Whether ANMOL is live in West Bengal** — could not be confirmed either way; no assertion made.

---

## 9. References

### A. Guidelines and normative sources
1. **World Health Organization.** *Guideline: Recommendations on Digital Interventions for Health System Strengthening.* Geneva: WHO; 2019. (Recommendation 7 — health-worker decision support; Recommendation 8 — digital tracking **combined with** decision support.) Executive summary: https://www.ncbi.nlm.nih.gov/books/NBK541888/ · Full guideline: https://www.ncbi.nlm.nih.gov/books/NBK541902/

### B. Trials and evaluations of frontline-worker digital health in India
2. **Modi D, et al.** Effectiveness of a mobile-phone intervention (ImTeCHO) to improve community health worker performance: cluster randomised trial. *PLOS Medicine.* 2019. https://journals.plos.org/plosmedicine/article?id=10.1371%2Fjournal.pmed.1002939
3. **Modi D, et al.** Cost-effectiveness of ImTeCHO. *JMIR mHealth uHealth.* 2020;8(10):e17066. https://pmc.ncbi.nlm.nih.gov/articles/PMC7593859/ *(Note: the "16% mortality reduction" is a per-protocol figure from this paper — the RCT (ref 2) found no mortality effect.)*
4. **TECHO+ state-scale evaluation (Gujarat).** *Frontiers in Public Health.* 2022. https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2022.856561/full
5. **Nagar R, et al.** Cluster randomised trial of a digital pendant and voice-reminder platform (Khushi Baby), Udaipur. *Vaccine.* 2018. https://pubmed.ncbi.nlm.nih.gov/29162321/
6. **Mohan D, et al.** Kilkari: individually randomised controlled trial, Madhya Pradesh. *BMJ Global Health.* 2022. https://pmc.ncbi.nlm.nih.gov/articles/PMC9288869/
7. **Bashingwa JJH, et al.** Kilkari reach and exposure across 13 states. *BMJ Global Health.* https://pmc.ncbi.nlm.nih.gov/articles/PMC9366343/
8. **Mobile Academy** reach and completion across 13 states. https://pmc.ncbi.nlm.nih.gov/articles/PMC8386225/
9. **Kilkari equity analysis** (caste, education, phone ownership). https://pmc.ncbi.nlm.nih.gov/articles/PMC8327823/
10. **Prinja S, et al.** ReMiND (CommCare ASHA job aid with decision support), Uttar Pradesh — impact and cost-effectiveness. *Cost Effectiveness and Resource Allocation.* 2018;16:25. https://pmc.ncbi.nlm.nih.gov/articles/PMC6020234/
11. **ICT-CCS cluster randomised trial** (CARE India, Bihar). https://pmc.ncbi.nlm.nih.gov/articles/PMC6875677/
12. **Avula R, et al.** ICDS-CAS evaluation (Madhya Pradesh, Bihar). *BMJ Global Health.* 2022. https://pmc.ncbi.nlm.nih.gov/articles/PMC9296874/
13. **ICDS-CAS qualitative study** (Anganwadi workers' experience). https://pmc.ncbi.nlm.nih.gov/articles/PMC6961923/
14. **Murthy N, et al.** mMitra: maternal knowledge and practices. https://pmc.ncbi.nlm.nih.gov/articles/PMC7268375/
15. **mMitra:** infant-care knowledge and practices. https://pmc.ncbi.nlm.nih.gov/articles/PMC6823296/
16. **ARMMAN authors.** *The Elusive Path Toward Measuring Health Outcomes: Lessons Learned From a Pseudo-Randomized Controlled Trial of a Large-Scale Mobile Health Initiative.* https://pmc.ncbi.nlm.nih.gov/articles/PMC6724498/
17. **E-IMNCI (Jharkhand)** — digitised deterministic IMNCI decision support for ANMs. https://pmc.ncbi.nlm.nih.gov/articles/PMC10603548/
18. **Perception and experiences of Auxiliary Nurse Midwives with ANMOL** (Salon block, Raebareli). *Indian Journal of Community Medicine.* 2026;51(2):358–365. https://journals.lww.com/ijcm/fulltext/2026/03000/perception_and_experiences_of_auxiliary_nurse.21.aspx
19. **e-Sanjeevani adoption and utilisation analysis.** *Oxford Open Digital Health.* 2025. https://pmc.ncbi.nlm.nih.gov/articles/PMC12558045/ *(Source of the "critical gap" statement on referral-loop closure.)*
20. **Sharma A, et al.** Data quality of the HMIS/RCH reporting system, Haryana. *PLOS ONE.* 2016;11(2):e0148449. https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0148449
21. **Sondaal SFV, et al.** Assessing the effect of mHealth interventions on maternal, neonatal and child health in LMICs: systematic review. *PLOS ONE.* https://pmc.ncbi.nlm.nih.gov/articles/PMC4643860/
22. **mHealth in the high-burden ("BIMARU") states — a review.** https://pmc.ncbi.nlm.nih.gov/articles/PMC10836675/
23. **Ayushman Bharat Digital Mission — implementation barriers.** https://pmc.ncbi.nlm.nih.gov/articles/PMC11855927/
24. **"Pilotitis" in digital health.** *Frontiers in Digital Health.* https://pmc.ncbi.nlm.nih.gov/articles/PMC12894408/

### C. ASHA workforce, burden and documentation
25. **Furtado KM, Mehndiratta A, Bauhoff S, Pawar S, Luo A, Jha A, McConnell M.** Community health worker payment processes: a qualitative assessment of experiences in two Indian states. *Health Policy and Planning.* 2025;40(4):483–495. doi:10.1093/heapol/czaf010. https://academic.oup.com/heapol/article/40/4/483/8015911 *(Source of the peer-reviewed "**more than ten registers**, one per incentive category" finding.)*
26. **Khandre RR, Jakasania A, Raut A.** "We are working for seven days a week": time-motion study of ASHAs in central India. *Medical Journal Armed Forces India.* 2022;79(Suppl 1):S142–S149. https://pmc.ncbi.nlm.nih.gov/articles/PMC10746798/ *(41 min/day on register maintenance.)*
27. **Patel S, Tandon P.** Challenges in data documentation and retrieval in the ASHA diary from a usability perspective. *Social Science & Medicine.* 2025. https://www.sciencedirect.com/science/article/abs/pii/S0277953625007014
28. **Job satisfaction of ASHA workers, Bhatar block, Purba Bardhaman, West Bengal.** *International Journal of Community Medicine and Public Health.* https://www.ijcmph.com/index.php/ijcmph/article/view/4499
29. **Dutta S, Chakrabarti S, Basu M, Manna S.** Challenges faced by Community Health Officers and beneficiary satisfaction with telemedicine (Swasthya Ingit) at Health & Wellness Centres, West Bengal. *Indian Journal of Community Medicine.* 2025;50(2):361–367. https://pmc.ncbi.nlm.nih.gov/articles/PMC12080889/

### D. Statistics — primary government sources
30. **IIPS and ICF.** *National Family Health Survey (NFHS-5), 2019–21: West Bengal.* Mumbai: IIPS. https://dhsprogram.com/pubs/pdf/FR374/FR374_WestBengal.pdf
31. **IIPS and ICF.** *National Family Health Survey (NFHS-5), 2019–21: India, Volume I.* Mumbai: IIPS. https://dhsprogram.com/pubs/pdf/FR375/FR375.pdf
32. **Registrar General of India.** *SRS Special Bulletin on Maternal Mortality in India, 2018–20.* https://censusindia.gov.in/nada/index.php/catalog/44379/download/48052/SRS_MMR_Bulletin_2018_2020.pdf
33. **Registrar General of India.** *SRS Special Bulletin on Maternal Mortality in India, 2019–21* (released 7 May 2025). https://censusindia.gov.in/nada/index.php/catalog/45561/download/49758/SRS_MMR_Bulletin_2019_2021.pdf
34. **Registrar General of India.** *SRS Statistical Bulletin 2023, Vol. 58 No. 1.* https://censusindia.gov.in/nada/index.php/catalog/46178/download/50426/SRS_Bulletin_2023_Vol_58_No_1.pdf
35. **National Health Systems Resource Centre (NHSRC).** State-wise ASHA numbers. https://nhsrcindia.org/asha-map-table *(West Bengal: 65,743.)*
36. **Government of West Bengal.** Swasthya Sathi — key functionality. https://swasthyasathi.gov.in/KeyFunctionality

### E. Grey literature and field reporting
37. **Sreerupa, Makkad S, Rajeev A.** Is digitalisation a double-edged sword for workers in India's public healthcare system? *Ideas for India*, 2024. https://www.ideasforindia.in/topics/productivity-innovation/is-digitalisation-a-double-edged-sword-for-workers-in-indias-public-healthcare-system *(Haryana: parallel paper records; MDM360 Shield recalled after ASHA collective action.)*
38. **Chakraborty R.** India's digital health push is overworking its front-line women. *New Lines Magazine*, 31 March 2026. https://newlinesmag.com/reportage/indias-digital-health-push-is-overworking-its-front-line-women/ *(Source of "Now we do everything twice — once online, and again on paper.")*
39. **Behanbox.** Why a photo-backed attendance app is distressing Maharashtra's ASHA workers, 6 April 2025. https://behanbox.com/2025/04/06/why-a-photo-backed-attendance-app-is-distressing-maharashtras-asha-workers/ *(The Hajeri app, discontinued after protest.)*
40. **Data & Society.** From care labor to data labor: India's door-to-door health activists. https://datasociety.net/points/from-care-labor-to-data-labor-indias-door-to-door-health-activists/
41. **Masoodi S.** When care work becomes data work. *DataSyn*, 6 May 2026. https://datasyn.substack.com/p/when-care-work-becomes-data-work
42. **BOOM.** AI facial recognition is denying food to pregnant women across India. https://www.boomlive.in/decode/ai-facial-recognition-is-denying-food-to-pregnant-women-across-india-30878
43. **ThePrint.** Unhappy with pay hike, ASHA workers protest outside Bengal health department HQ, 6 February 2026. https://theprint.in/india/unhappy-with-pay-hike-asha-workers-protest-outside-bengal-health-department-hq/2847628/

### F. Language and accessibility
44. **Nahar, Ruparel, Kabir, Khan, Saha, Rashid.** *AmarDoctor:* AI-driven clinical decision support for Bengali speakers. arXiv preprint 2510.24724, 30 October 2025. https://arxiv.org/pdf/2510.24724 — ⚠️ *Preprint, not peer-reviewed; Bangladesh-authored. Cited **only** for its documentation of Bengali as an underserved, low-resource language in digital health and of the Bengali-keyboard barrier — **not** for its country statistics.*

### G. Project documentation — ASHAMitra (internal)
45. `assets/data/asha_engine.json` — clinical rule engine v2.6.0 (7 modules, 68 questions, 127 rules).
46. `docs/MODULES.md` · `docs/PIPELINE.md` · `docs/SIGNOFF_RULES.md` — full rule set, the 11-layer decision pipeline, and the 64 rules awaiting clinical sign-off.
