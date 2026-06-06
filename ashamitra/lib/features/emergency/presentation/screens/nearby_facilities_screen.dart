import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/referral_map/referral_map_widget.dart';

/// Standalone "nearby health facilities" map.
///
/// Opened when the worker asks the assistant about nearby hospitals / health
/// centres / how far / how long. It uses the device GPS + OSRM through
/// [ReferralMapWidget] to show REAL road distances and drive times — so the
/// assistant never has to invent ("guess") distances or times.
class NearbyFacilitiesScreen extends StatelessWidget {
  const NearbyFacilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: 'nearby_centers_title'.tr),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ReferralMapWidget(
                    facilityType: 'CHC',
                    mapHeight: h * 0.52,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
