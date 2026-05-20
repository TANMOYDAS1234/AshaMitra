// ─────────────────────────────────────────────────────────────────────────────
// Layer 10 — Referral Decision Engine
// Computes the final referral destination, urgency, max delay minutes,
// and transport advisory from:
//   - Final band (from Layer 9)
//   - Module-specific referral from winning rule
//   - Distance to FRU
//   - Ambulance status
//   - Follow-up rules from asha_engine.json
// ─────────────────────────────────────────────────────────────────────────────

class ReferralResult {
  final String facilityType;
  final String urgency;
  final int maxDelayMinutes;
  final String transportAction;
  final bool ambulanceCalled;
  final double? distanceToFruKm;
  final int estimatedTravelMinutes; // estimated from distance
  final bool followupRequired;
  final int recheckAfterHours;
  final String followupTrigger;
  final List<String> referralActions; // ordered action steps for ASHA

  const ReferralResult({
    required this.facilityType,
    required this.urgency,
    required this.maxDelayMinutes,
    required this.transportAction,
    required this.ambulanceCalled,
    required this.distanceToFruKm,
    required this.estimatedTravelMinutes,
    required this.followupRequired,
    required this.recheckAfterHours,
    required this.followupTrigger,
    required this.referralActions,
  });

  Map<String, dynamic> toMap() => {
    'facility_type': facilityType,
    'urgency': urgency,
    'max_delay_minutes': maxDelayMinutes,
    'transport_action': transportAction,
    'ambulance_called': ambulanceCalled,
    'distance_to_fru_km': distanceToFruKm,
    'estimated_travel_minutes': estimatedTravelMinutes,
    'followup': {
      'required': followupRequired,
      'recheck_after_hours': recheckAfterHours,
      'trigger': followupTrigger,
    },
    'referral_actions': referralActions,
  };
}

class ReferralDecisionEngine {
  // Average rural road speed assumption: 30 km/h
  static const _avgSpeedKmh = 30.0;

  // Facility type per module per band
  static const _facilityMap = <String, Map<String, String>>{
    'newborn': {
      'RED':    'SNCU / FRU immediately',
      'YELLOW': 'PHC within 24 h',
      'GREEN':  'Home care',
    },
    'child': {
      'RED':    'FRU / DH immediately',
      'YELLOW': 'PHC within 24 h',
      'GREEN':  'Home care',
    },
    'pregnancy': {
      'RED':    'FRU / DH immediately',
      'YELLOW': 'PHC within 24 h',
      'GREEN':  'Routine ANC at PHC',
    },
    'delivery_pnc': {
      'RED':    'FRU / DH immediately',
      'YELLOW': 'PHC within 24 h',
      'GREEN':  'Home care',
    },
    'immunisation': {
      'RED':    'PHC / FRU same day',
      'YELLOW': 'Nearest immunisation session within 7 days',
      'GREEN':  'Routine immunisation schedule',
    },
    'emergency': {
      'RED':    'FRU / SNCU / DH immediately',
      'YELLOW': 'PHC within 24 h',
      'GREEN':  'Home care',
    },
  };

  // Max delay minutes per band
  static const _maxDelayMap = <String, int>{
    'RED':    30,
    'YELLOW': 1440, // 24 hours
    'GREEN':  0,
  };

  // Urgency label per band
  static const _urgencyMap = <String, String>{
    'RED':    'Immediate',
    'YELLOW': 'Within 24 hours',
    'GREEN':  'Routine',
  };

  /// Computes the full referral decision.
  ///
  /// [finalBand]       — from Layer 9
  /// [moduleId]        — current module
  /// [ruleReferral]    — referral string from winning rule (may be empty)
  /// [ambulanceCalled] — from patient_case.json transport field
  /// [distanceKm]      — from patient_case.json transport field
  /// [followupRules]   — from asha_engine.json followup_rules
  ReferralResult decide({
    required String finalBand,
    required String moduleId,
    required String ruleReferral,
    required bool ambulanceCalled,
    required double? distanceKm,
    required Map<String, dynamic> followupRules,
  }) {
    // ── Facility type ─────────────────────────────────────────────────────────
    final moduleMap = _facilityMap[moduleId] ?? _facilityMap['emergency']!;
    final facilityType = ruleReferral.isNotEmpty
        ? ruleReferral
        : moduleMap[finalBand] ?? 'Home care';

    // ── Urgency + max delay ───────────────────────────────────────────────────
    final urgency         = _urgencyMap[finalBand] ?? 'Routine';
    final maxDelayMinutes = _maxDelayMap[finalBand] ?? 0;

    // ── Travel time estimate ──────────────────────────────────────────────────
    final estimatedTravelMinutes = distanceKm != null
        ? (distanceKm / _avgSpeedKmh * 60).round()
        : 0;

    // ── Transport advisory ────────────────────────────────────────────────────
    final String transportAction;
    if (finalBand == 'RED') {
      if (!ambulanceCalled) {
        transportAction = 'Call 108 immediately — ambulance not yet called.';
      } else {
        transportAction = 'Ambulance called. Keep patient stable during transport.';
      }
    } else if (finalBand == 'YELLOW') {
      transportAction = distanceKm != null
          ? 'Arrange transport to PHC (~${estimatedTravelMinutes} min away).'
          : 'Arrange transport to nearest PHC.';
    } else {
      transportAction = 'No transport required. Home care.';
    }

    // ── Follow-up ─────────────────────────────────────────────────────────────
    final followupTrigger = finalBand == 'RED' ? 'RED_REFUSED' : finalBand;
    final recheckHours    = _followupHours(followupTrigger, followupRules);
    final followupRequired = finalBand != 'GREEN';

    // ── Referral action steps ─────────────────────────────────────────────────
    final referralActions = _buildReferralActions(
      band: finalBand,
      facilityType: facilityType,
      ambulanceCalled: ambulanceCalled,
      distanceKm: distanceKm,
      estimatedTravelMinutes: estimatedTravelMinutes,
      recheckHours: recheckHours,
    );

    return ReferralResult(
      facilityType: facilityType,
      urgency: urgency,
      maxDelayMinutes: maxDelayMinutes,
      transportAction: transportAction,
      ambulanceCalled: ambulanceCalled,
      distanceToFruKm: distanceKm,
      estimatedTravelMinutes: estimatedTravelMinutes,
      followupRequired: followupRequired,
      recheckAfterHours: recheckHours,
      followupTrigger: followupTrigger,
      referralActions: referralActions,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  int _followupHours(String trigger, Map<String, dynamic> followupRules) {
    final rule = followupRules[trigger] as Map<String, dynamic>?;
    if (rule != null) return (rule['hours'] as num).toInt();
    if (trigger == 'RED_REFUSED') return 4;
    if (trigger == 'YELLOW') return 24;
    return 0;
  }

  List<String> _buildReferralActions({
    required String band,
    required String facilityType,
    required bool ambulanceCalled,
    required double? distanceKm,
    required int estimatedTravelMinutes,
    required int recheckHours,
  }) {
    final actions = <String>[];

    if (band == 'RED') {
      if (!ambulanceCalled) actions.add('এখনই ১০৮ কল করুন।');
      actions.add('$facilityType-তে রেফার করুন (≤ ৩০ মিনিট)।');
      if (distanceKm != null) {
        actions.add('দূরত্ব: ${distanceKm.toStringAsFixed(1)} কিমি '
            '(আনুমানিক $estimatedTravelMinutes মিনিট)।');
      }
      actions.add('পরিবহনে বিলম্ব করবেন না।');
      actions.add('ANM/MO-কে এখনই জানান।');
    } else if (band == 'YELLOW') {
      actions.add('২৪ ঘণ্টার মধ্যে $facilityType-তে রেফার করুন।');
      actions.add('${recheckHours} ঘণ্টা পর পুনরায় পরীক্ষা করুন।');
      actions.add('বিপদচিহ্ন বাড়লে এখনই রেফার করুন।');
    } else {
      actions.add('বাড়িতে যত্ন নিন।');
      actions.add('রুটিন ফলো-আপ করুন।');
      actions.add('বিপদচিহ্ন দেখা দিলে PHC-তে যান।');
    }

    return actions;
  }
}
