import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';

/// Shared "remind the patient" flow (Call / WhatsApp / SMS + backend log),
/// reused by the due-list screen and the checkup patient-picker so there is a
/// single source of truth for the reminder message + channel handling.
class ReminderService {
  /// Shows the channel sheet, opens the dialer / WhatsApp / SMS with a prefilled
  /// Bengali message, then logs the reminder. Returns the updated
  /// `{lastRemindedAt, lastReminderChannel}` (or null if cancelled / no number /
  /// not yet synced to a server id).
  static Future<Map<String, dynamic>?> remind(
      BuildContext context, Map<String, dynamic> e) async {
    final mobile = (e['patientMobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (mobile.isEmpty) {
      Get.snackbar('নম্বর নেই', 'এই রোগীর মোবাইল নম্বর নেই — রেজিস্ট্রেশনে যোগ করুন।',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warningYellow,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
      return null;
    }
    final channel = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call, color: AppColors.safeGreen),
              title: const Text('ফোন করুন'),
              subtitle: Text(mobile),
              onTap: () => Navigator.pop(context, 'call'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble, color: Color(0xFF25D366)),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined, color: AppColors.primary),
              title: const Text('SMS'),
              onTap: () => Navigator.pop(context, 'sms'),
            ),
          ],
        ),
      ),
    );
    if (channel == null) return null;
    final msg = reminderMsg(e);
    final wa = mobile.length == 10 ? '91$mobile' : mobile;
    final uri = switch (channel) {
      'whatsapp' => Uri.parse('https://wa.me/$wa?text=${Uri.encodeComponent(msg)}'),
      'sms' => Uri.parse('sms:$mobile?body=${Uri.encodeComponent(msg)}'),
      _ => Uri.parse('tel:$mobile'),
    };
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      Get.snackbar('খুলতে পারিনি', 'অ্যাপটি খোলা গেল না।',
          snackPosition: SnackPosition.BOTTOM);
    }
    final id = (e['id'] ?? '').toString();
    if (id.isEmpty) return null; // not yet a server event → can't log
    return ApiService.logReminder(id, channel);
  }

  /// Prefilled reminder message, tailored to the visit kind.
  static String reminderMsg(Map<String, dynamic> e) {
    final name = (e['patientName'] ?? 'রোগী').toString();
    final label = (e['label'] ?? '').toString();
    final due = _dueText(e);
    final kind = (e['kind'] ?? '').toString();
    if (kind == 'anc') {
      return 'নমস্কার, $name এর ANC পরীক্ষা ($label) $due। অনুগ্রহ করে নিকটতম স্বাস্থ্যকেন্দ্রে যান।';
    }
    if (kind == 'vaccine') {
      return '$name এর টিকা ($label) $due। সময়মতো অঙ্গনওয়াড়ি বা স্বাস্থ্যকেন্দ্রে টিকা দিন।';
    }
    return '$name — $label: $due।';
  }

  /// "মনে করানো হয়েছে (channel) — when" hint, or null if never reminded.
  static String? lastRemindedText(Map<String, dynamic> e) {
    final at = e['lastRemindedAt']?.toString();
    if (at == null || at.isEmpty) return null;
    final dt = DateTime.tryParse(at);
    if (dt == null) return null;
    final days = DateTime.now().difference(dt).inDays;
    final chBn = switch ((e['lastReminderChannel'] ?? '').toString()) {
      'call' => 'ফোন',
      'whatsapp' => 'WhatsApp',
      'sms' => 'SMS',
      _ => '',
    };
    final whenBn = days <= 0 ? 'আজ' : '$days দিন আগে';
    return 'মনে করানো হয়েছে ($chBn) — $whenBn';
  }

  // Human due text computed from dueDate (robust when daysUntil isn't present).
  static String _dueText(Map<String, dynamic> e) {
    final dd = DateTime.tryParse((e['dueDate'] ?? '').toString());
    if (dd == null) return '';
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final due0 = DateTime(dd.year, dd.month, dd.day);
    final days = due0.difference(d0).inDays;
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${two(dd.day)}/${two(dd.month)}/${dd.year}';
    if (days < 0) return '${days.abs()} দিন পার হয়ে গেছে ($date)';
    if (days == 0) return 'আজ ($date)';
    return 'আগামী $date ($days দিন পরে)';
  }
}
