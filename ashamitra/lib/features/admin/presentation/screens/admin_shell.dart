import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../admin/controller/admin_controller.dart';
import 'admin_overview_tab.dart';
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
  }

  void _onTabChanged(int i) {
    setState(() => _index = i);
    final ctrl = Get.find<AdminController>();
    switch (i) {
      case 0:
        ctrl.loadStats();
        ctrl.loadReports();
      case 1:
        ctrl.loadAshaWorkers();
      case 2:
        ctrl.loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabChanged,
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black12,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primary),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: AppColors.primary),
            label: 'Workers',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
