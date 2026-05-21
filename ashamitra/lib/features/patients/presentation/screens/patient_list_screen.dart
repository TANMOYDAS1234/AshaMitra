import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../../shared/widgets/patient_card.dart';
import '../../../../shared/widgets/risk_badge.dart';
import '../../../../shared/components/bottom_nav.dart';
import '../../controller/patient_controller.dart';
import '../../data/models/patient_model.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  late final PatientController _ctrl;
  int _filterIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<PatientController>()
        ? Get.find<PatientController>()
        : Get.put(PatientController(), permanent: true);
  }

  static const _filters = ['All', 'Pregnancy', 'Newborn', 'Child', 'High Risk'];

  List<PatientModel> get _filtered => _ctrl.patients.where((p) {
        final name = p.name;
        final type = p.type;
        final village = p.village;
        final risk = p.riskFromOutcome;

        final matchSearch =
            name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                village.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchFilter = _filterIndex == 0 ||
            (_filterIndex == 4
                ? risk == RiskLevel.high || risk == RiskLevel.emergency
                : _typeMatchesFilter(type, _filters[_filterIndex]));
        return matchSearch && matchFilter;
      }).toList();

  // Matches a patient's type string against a filter chip. `type` is English
  // for manually added patients but Bengali for triage-created ones
  // (PatientController._caseLabel), so both spellings must be checked.
  static bool _typeMatchesFilter(String type, String filter) {
    final t = type.toLowerCase();
    return switch (filter) {
      'Pregnancy' => t.contains('pregnan') || type.contains('গর্ভ'),
      'Newborn'   => t.contains('newborn') || type.contains('নবজাতক'),
      'Child'     => t.contains('child') ||
          t.contains('infant') ||
          type.contains('শিশু'),
      _           => true,
    };
  }

  Future<void> _downloadPdf() async {
    final list = _filtered;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text('ASHA Mitra — Patient List',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Generated: ${DateTime.now().toString().substring(0, 16)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Text('Total patients: ${list.length}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Divider(height: 24),
          pw.Table.fromTextArray(
            headers: ['Name', 'Type', 'Village', 'Last Visit', 'Risk'],
            data: list.map((p) => [
              p.name,
              p.type,
              p.village,
              p.lastVisit,
              p.riskFromOutcome.name.toUpperCase(),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo100),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    await PdfHelper.saveAndOpen(doc, 'asha_mitra_patients_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Patients',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onBackground)),
                    ),
                    GestureDetector(
                      onTap: _downloadPdf,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download_rounded, color: AppColors.primary, size: 16),
                            SizedBox(width: 4),
                            Text('PDF', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Get.toNamed(AppRoutes.addPatient),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search patient or village...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filters.length,
                  itemBuilder: (_, i) {
                    final sel = i == _filterIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _filterIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(
                            color: sel ? AppColors.primary.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                            blurRadius: 8, offset: const Offset(0, 2),
                          )],
                        ),
                        child: Text(_filters[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : AppColors.textSecondary,
                            )),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Obx(() {
                  if (_ctrl.isLoading.value && _ctrl.patients.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                    );
                  }
                  final list = _filtered;
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 56, color: AppColors.textLight),
                          const SizedBox(height: 12),
                          Text('patient_empty'.tr,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _ctrl.syncFromServer,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return Dismissible(
                          key: ValueKey(p.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('রোগী মুছুন'),
                                content: Text('"${p.name}" তালিকা থেকে মুছে ফেলবেন?'),
                                actions: [
                                  TextButton(onPressed: () => Get.back(result: false), child: const Text('বাতিল')),
                                  TextButton(
                                    onPressed: () => Get.back(result: true),
                                    child: const Text('মুছুন', style: TextStyle(color: AppColors.emergencyRed)),
                                  ),
                                ],
                              ),
                            ) ?? false;
                          },
                          onDismissed: (_) => _ctrl.deletePatient(p.id),
                          child: PatientCard(
                            name: p.name,
                            caseType: p.type,
                            village: p.village,
                            lastVisit: p.lastVisit,
                            riskLevel: p.riskFromOutcome,
                            onTap: () => Get.toNamed(AppRoutes.patientProfile, arguments: p.toJson()),
                            onCallTap: p.mobile.isNotEmpty
                                ? () => launchUrl(Uri.parse('tel:${p.mobile}'))
                                : null,
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}
