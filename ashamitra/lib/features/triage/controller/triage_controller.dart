import 'package:get/get.dart';
import 'package:asha_mitra/core/services/rule_executor.dart';

class TriageController extends GetxController {
  // ── Patient case fields ───────────────────────────────────────────────────
  final caseId       = ''.obs;
  final moduleId     = ''.obs;
  final patientId    = ''.obs;
  final patientName  = ''.obs;
  final ashaId       = ''.obs;
  final situation    = ''.obs;

  // ── Answers: questionId → dynamic (bool | String) ────────────────────────
  final answers = <String, dynamic>{}.obs;

  // ── Vitals: vitalKey → num ────────────────────────────────────────────────
  final vitals = <String, dynamic>{}.obs;

  // ── Transport ─────────────────────────────────────────────────────────────
  final ambulanceCalled    = false.obs;
  final distanceToFruKm   = Rxn<double>();

  // ── Questions for current module ──────────────────────────────────────────
  final questions = <EngineQuestion>[].obs;
  final currentIndex = 0.obs;

  // ── Result ────────────────────────────────────────────────────────────────
  final Rxn<DecisionOutput> result = Rxn<DecisionOutput>();
  final isLoading = false.obs;

  // ── Convenience getters ───────────────────────────────────────────────────
  bool get hasResult => result.value != null;
  bool get isRedLocked => result.value?.redLock ?? false;
  EngineQuestion? get currentQuestion =>
      currentIndex.value < questions.length ? questions[currentIndex.value] : null;

  // ── Session setup ─────────────────────────────────────────────────────────
  void startSession({
    required String module,
    required String caseType,
    String? patient,
    String? asha,
    String? sit,
  }) {
    moduleId.value   = module;
    caseId.value     = caseType;
    patientId.value  = patient ?? '';
    patientName.value = patient ?? '';
    ashaId.value     = asha ?? '';
    situation.value  = sit ?? '';
    answers.clear();
    vitals.clear();
    result.value = null;
    currentIndex.value = 0;
    ambulanceCalled.value = false;
    distanceToFruKm.value = null;
  }

  // ── Answer recording ──────────────────────────────────────────────────────
  void answerQuestion(String questionId, dynamic answer) {
    answers[questionId] = answer;
    // Re-sweep after every answer — re-sweep invariant
    _evaluate();
    if (isRedLocked) return; // hard-stop: no need to advance
    if (currentIndex.value < questions.length - 1) {
      currentIndex.value++;
    }
  }

  // ── Vital recording ───────────────────────────────────────────────────────
  void recordVital(String key, num value) {
    vitals[key] = value;
    _evaluate();
  }

  // ── Transport ─────────────────────────────────────────────────────────────
  void setTransport({required bool called, double? distanceKm}) {
    ambulanceCalled.value = called;
    distanceToFruKm.value = distanceKm;
    _evaluate();
  }

  // ── Manual full evaluate (called by result screen) ────────────────────────
  DecisionOutput evaluate({
    required String module,
    required Map<String, dynamic> rawAnswers,
    Map<String, dynamic> rawVitals = const {},
    String case_ = '',
    bool ambulance = false,
    double? distKm,
  }) {
    final out = Get.find<RuleExecutor>().execute(
      moduleId: module,
      answers: rawAnswers,
      vitals: rawVitals,
      caseId: case_,
      ambulanceCalled: ambulance,
      distanceKm: distKm,
    );
    result.value = out;
    return out;
  }

  // ── Internal re-sweep ─────────────────────────────────────────────────────
  void _evaluate() {
    if (moduleId.value.isEmpty) return;
    result.value = Get.find<RuleExecutor>().execute(
      moduleId: moduleId.value,
      answers: Map<String, dynamic>.from(answers),
      vitals: Map<String, dynamic>.from(vitals),
      caseId: caseId.value,
      ambulanceCalled: ambulanceCalled.value,
      distanceKm: distanceToFruKm.value,
    );
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  void reset() {
    answers.clear();
    vitals.clear();
    questions.clear();
    result.value = null;
    currentIndex.value = 0;
    moduleId.value = '';
    caseId.value = '';
    ambulanceCalled.value = false;
    distanceToFruKm.value = null;
  }
}
