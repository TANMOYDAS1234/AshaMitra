import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/controller/auth_controller.dart';
import '../../controller/programmes_controller.dart';

/// National Health Programmes.
///
/// A CMHO does not run one programme, she runs all of them — NTEP, NCD, family
/// planning, civil registration, drug logistics — and the district screen only
/// ever answered RCH. This is the rest of her job, built strictly from data the
/// app already collects.
///
/// Every programme leads with what must be DONE and to WHOM. A supervisor acts
/// on "Rahim Sheikh, 4 doses missed, Kolkata — call him", never on "adherence 87%".
class ProgrammesScreen extends StatefulWidget {
  const ProgrammesScreen({super.key});

  @override
  State<ProgrammesScreen> createState() => _ProgrammesScreenState();
}

class _ProgrammesScreenState extends State<ProgrammesScreen> {
  final c = Get.put(ProgrammesController(), tag: 'programmes');
  final _auth = Get.find<AuthController>();
  final _open = <String>{}.obs;

  @override
  void initState() {
    super.initState();
    if (c.programmes.isEmpty) c.load();
  }

  String get _scope => switch (_auth.user.value?.panelRole) {
        'cmho' => 'জেলা',
        'bmho' => 'ব্লক',
        _ => 'উপকেন্দ্র',
      };

  @override
  Widget build(BuildContext context) {
    final panel = _auth.user.value?.roleShort ?? '';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'স্বাস্থ্য কর্মসূচি',
                subtitle: '$panel · $_scope · জাতীয় কর্মসূচির অবস্থা',
                actions: [
                  IconButton(
                    onPressed: () => c.load(),
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ),
              Expanded(
                child: Obx(() {
                  if (c.loading.value && c.programmes.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (c.error.isNotEmpty && c.programmes.isEmpty) {
                    return EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'তথ্য পাওয়া যায়নি',
                      subtitle: c.error.value,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => c.load(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      children: [
                        _periodToggle(),
                        const SizedBox(height: 12),
                        ...c.programmes.map(_programmeCard),
                        const SizedBox(height: 16),
                        _scopeNote(),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodToggle() => Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [3, 12].map((m) {
          final sel = c.months.value == m;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Material(
              color: sel ? AppColors.primary : AppColors.surface,
              borderRadius: AppRadius.pillR,
              child: InkWell(
                borderRadius: AppRadius.pillR,
                onTap: sel ? null : () => c.load(months: m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Text('$m মাস',
                      style: AppTextStyles.label.copyWith(
                        color: sel ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ),
            ),
          );
        }).toList(),
      ));

  Widget _programmeCard(Programme p) {
    return Obx(() {
      final open = _open.contains(p.key);
      final urgent = p.urgentCount;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlR,
          boxShadow: AppShadows.low,
          border: urgent > 0
              ? Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.28))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: AppRadius.xlR,
              onTap: () => open ? _open.remove(p.key) : _open.add(p.key),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (urgent > 0
                                    ? AppColors.emergencyRed
                                    : AppColors.primary)
                                .withValues(alpha: 0.10),
                            borderRadius: AppRadius.mdR,
                          ),
                          child: Icon(_icon(p.icon),
                              size: 20,
                              color: urgent > 0
                                  ? AppColors.emergencyRed
                                  : AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p.name, style: AppTextStyles.h3)),
                        if (urgent > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed,
                              borderRadius: AppRadius.smR,
                            ),
                            child: Text('$urgent',
                                style: AppTextStyles.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ),
                        const SizedBox(width: 6),
                        Icon(
                            open
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      children: p.headline.map(_stat).toList(),
                    ),
                  ],
                ),
              ),
            ),
            if (open) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.liveActions.isEmpty)
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 18, color: AppColors.safeGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('এই মুহূর্তে কিছু করার নেই',
                                style: AppTextStyles.bodySm
                                    .copyWith(color: AppColors.safeGreen)),
                          ),
                        ],
                      )
                    else
                      ...p.liveActions.map(_action),
                    if (p.blocks.any((b) => b.flagged > 0)) ...[
                      const SizedBox(height: 12),
                      Text('ব্লক অনুযায়ী',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      ...p.blocks
                          .where((b) => b.flagged > 0)
                          .map((b) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Text(b.block,
                                            style: AppTextStyles.bodySm)),
                                    Text('${b.flagged}/${b.total}',
                                        style: AppTextStyles.label.copyWith(
                                            color: AppColors.emergencyRed)),
                                  ],
                                ),
                              )),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _stat(ProgStat s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.display,
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w800,
              // "—" is a real state (no denominator), not a failure. Render it
              // calm and grey so it reads as "not measured yet", not as zero.
              color: s.value == null
                  ? AppColors.textLight
                  : s.alarm
                      ? AppColors.emergencyRed
                      : AppColors.onBackground,
            ),
          ),
          Text(s.label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      );

  Widget _action(ProgAction a) {
    final col = a.severity == 'high'
        ? AppColors.emergencyRed
        : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14,
                  decoration: BoxDecoration(
                      color: col, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(a.title,
                    style: AppTextStyles.label
                        .copyWith(color: col, fontWeight: FontWeight.w800)),
              ),
              Text('${a.rows.length}',
                  style: AppTextStyles.label.copyWith(color: col)),
            ],
          ),
          const SizedBox(height: 6),
          ...a.rows.take(8).map((r) => _row(r, col)),
          if (a.rows.length > 8)
            Padding(
              padding: const EdgeInsets.only(left: 11, top: 4),
              child: Text('+ আরও ${a.rows.length - 8} জন',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _row(ProgRow r, Color col) => Padding(
        padding: const EdgeInsets.only(left: 11, top: 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      style: AppTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    [r.detail, if (r.where.isNotEmpty) r.where].join(' · '),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // The point of naming a person is being able to reach them.
            if (r.mobile.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => launchUrl(Uri.parse('tel:${r.mobile}')),
                icon: Icon(Icons.phone_rounded, size: 18, color: col),
              ),
          ],
        ),
      );

  /// Honest about the boundary. A CMHO's real job includes surveillance,
  /// leprosy, blindness, budgets and postings — none of which this app collects.
  /// Saying so is better than letting a missing programme read as a healthy one.
  Widget _scopeNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.lgR,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'এখানে শুধু সেই কর্মসূচি দেখানো হয় যেগুলোর তথ্য ASHA কর্মীরা এই '
                'অ্যাপে তোলেন। ম্যালেরিয়া/ডেঙ্গু সার্ভেইল্যান্স, কুষ্ঠ, অন্ধত্ব — '
                'এগুলোর তথ্য এখনও সংগ্রহ করা হয় না, তাই দেখানো হয়নি।',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  IconData _icon(String k) => switch (k) {
        'tb' => Icons.coronavirus_rounded,
        'ncd' => Icons.monitor_heart_rounded,
        'fp' => Icons.family_restroom_rounded,
        'crs' => Icons.how_to_reg_rounded,
        'drug' => Icons.medication_rounded,
        _ => Icons.health_and_safety_rounded,
      };
}
