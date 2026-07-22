import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/panel_palette.dart';
import '../../../admin/controller/admin_controller.dart';
import 'admin_overview_tab.dart';
import 'admin_district_tab.dart';
import 'admin_workers_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_settings_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  final _tabs = const [
    AdminOverviewTab(),
    AdminDistrictTab(),
    AdminWorkersTab(),
    AdminReportsTab(),
    AdminSettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    final ctrl = Get.find<AdminController>();
    ctrl.loadStats();
    ctrl.loadAshaWorkers();
    ctrl.loadReports();
    // Pulled on open so the escalation badge is accurate before the CMHO ever
    // taps the District tab — the whole point is that they don't have to look.
    ctrl.loadDistrict();
    _syncFromController();
  }

  /// Mirrors the controller's tab index into local state, so a child screen can
  /// navigate the shell (the analytics tab's "see the dashboard" pointer) without
  /// the shell having to know that screen exists.
  void _syncFromController() {
    final ctrl = Get.find<AdminController>();
    ever<int>(ctrl.tabIndex, (i) {
      if (mounted && i != _index) _onTabChanged(i);
    });
  }

  void _onTabChanged(int i) {
    setState(() => _index = i);
    final ctrl = Get.find<AdminController>();
    if (ctrl.tabIndex.value != i) ctrl.tabIndex.value = i;
    switch (i) {
      case 0:
        ctrl.loadStats();
        ctrl.loadReports();
      case 1:
        ctrl.loadDistrict();
      case 2:
        ctrl.loadAshaWorkers();
      case 3:
        ctrl.loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabChanged,
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black12,
        indicatorColor: PanelPalette.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon:
                Icon(Icons.dashboard_rounded, color: PanelPalette.primary),
            label: 'Overview',
          ),
          NavigationDestination(
            // Badge carries the open-escalation count (maternal/infant deaths,
            // stranded referrals, stockouts, silent ASHAs).
            icon: Obx(() {
              final n = ctrl.dAlertCount;
              return Badge(
                isLabelVisible: n > 0,
                label: Text('$n'),
                backgroundColor: AppColors.emergencyRed,
                child: const Icon(Icons.insights_outlined),
              );
            }),
            selectedIcon: Obx(() {
              final n = ctrl.dAlertCount;
              return Badge(
                isLabelVisible: n > 0,
                label: Text('$n'),
                backgroundColor: AppColors.emergencyRed,
                child: Icon(Icons.insights_rounded,
                    color: PanelPalette.primary),
              );
            }),
            label: 'District',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: PanelPalette.primary),
            label: 'Workers',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon:
                Icon(Icons.bar_chart_rounded, color: PanelPalette.primary),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon:
                Icon(Icons.settings_rounded, color: PanelPalette.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
