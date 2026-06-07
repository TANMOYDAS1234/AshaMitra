// ─────────────────────────────────────────────────────────────────────────────
// PatientTriageContext — builds the engine's PatientDemographics + PriorVisit-
// History from a registered patient profile, so RuleExecutor's Adaptive Risk
// layer (age thresholds, prior-RED monitoring, HRP) actually fires.
//
// Both helpers are SAFE when no patient is selected (urgent walk-in): they
// return empty context, and the adaptive layer then applies no age/history
// escalation and never downgrades — the rule-based band stands. Register the
// patient and attach the report afterwards.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:get/get.dart';

import '../../features/patients/controller/patient_controller.dart';
import '../../features/patients/data/models/patient_model.dart';
import '../../shared/widgets/risk_badge.dart';
import 'rule_executor.dart'; // exports PatientDemographics, PriorVisitHistory

class PatientTriageContext {
  static PatientModel? lookup(String? id) {
    if (id == null || id.isEmpty) return null;
    if (!Get.isRegistered<PatientController>()) return null;
    for (final p in Get.find<PatientController>().patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Age (in the patient's own unit) + sex for the age-gated clinical rules.
  static PatientDemographics demographicsFor(String? patientId) {
    final p = lookup(patientId);
    if (p == null) return const PatientDemographics();
    final n = int.tryParse(p.age.trim());
    return PatientDemographics(
      ageDays: p.ageUnit == 'days' ? n : null,
      ageMonths: p.ageUnit == 'months' ? n : null,
      ageYears: p.ageUnit == 'years' ? n : null,
      sex: p.gender.trim().isEmpty ? null : p.gender.trim(),
    );
  }

  /// Minimal prior-visit history derived from the profile's last outcome/risk.
  /// Drives the "prior RED → closer monitoring (GREEN→YELLOW)" escalation.
  /// lastVisitDate is intentionally omitted so a stale record can't fire the
  /// <48h RED→escalation; the redBandCount path is the intended, safe signal.
  static PriorVisitHistory historyFor(String? patientId) {
    final p = lookup(patientId);
    if (p == null) return const PriorVisitHistory();
    final priorEmergency = p.outcome == 'emergency' || p.risk == RiskLevel.emergency;
    final priorAttention = p.outcome == 'attention' || p.risk == RiskLevel.high;
    return PriorVisitHistory(
      totalVisits: p.qaHistory.isNotEmpty ? 1 : 0,
      redBandCount: priorEmergency ? 1 : 0,
      yellowBandCount: priorAttention ? 1 : 0,
      lastBand: priorEmergency ? 'RED' : (priorAttention ? 'YELLOW' : null),
    );
  }
}
