import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';

/// Opens a patient's checkup as the structured **MCP-card visit form** (the
/// unified [VisitScreen]) — the app's single checkup flow for every case type.
///
/// "Dynamic per case": it loads the patient's schedule and opens their **next
/// pending visit** (soonest due, any kind — ANC / vaccine / HBNC / HBYC), and
/// the visit form renders the right MCP-card section for that kind. Completing
/// it records the visit, advances the schedule + reminders, and feeds the
/// per-patient report.
class CheckupLauncher {
  /// Returns true if a visit was opened (and completed), false otherwise — so a
  /// caller can refresh. Shows a brief loader while the schedule is fetched.
  static Future<bool> start({
    required String patientId,
    String patientName = '',
  }) async {
    if (patientId.isEmpty) return false;
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    List<dynamic> events;
    try {
      events = await ApiService.getScheduleForPatient(patientId);
    } catch (_) {
      events = const [];
    }
    if (Get.isDialogOpen ?? false) Get.back(); // close loader

    final pending = events
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['status']?.toString() ?? 'pending') == 'pending')
        .toList()
      // ISO date strings sort lexicographically → soonest-due first.
      ..sort((a, b) => (a['dueDate']?.toString() ?? '')
          .compareTo(b['dueDate']?.toString() ?? ''));

    if (pending.isEmpty) {
      Get.snackbar(
        'চেকআপ',
        'এখন কোনো Due চেকআপ নেই — LMP/DOB থেকে সূচি তৈরি হয় (অথবা সব ভিজিট সম্পন্ন)।',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warningYellow,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
      return false;
    }

    final ev = pending.first;
    ev['patientId'] ??= patientId;
    if (patientName.isNotEmpty) ev['patientName'] ??= patientName;
    final result = await Get.toNamed(AppRoutes.visit, arguments: ev);
    return result == true;
  }
}
