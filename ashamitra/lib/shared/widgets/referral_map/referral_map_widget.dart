import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';

class _Place {
  final String name;
  final LatLng pos;
  final String type;
  final double distanceKm;
  final bool isGovt; // PHC/CHC/DH/SNCU are government verified
  _Place({required this.name, required this.pos, required this.type, required this.distanceKm})
      : isGovt = ['PHC', 'CHC', 'DH', 'SNCU'].contains(type);
}

/// Road-routed polyline + drive distance/duration for a single
/// (origin, destination) pair, fetched from OSRM. The straight-line
/// distance on [_Place] remains the sort key (used to rank facilities)
/// — but anything visible to the worker (the drawn line on the map,
/// the chips, the summary card) uses these routed values when set.
class _Route {
  final List<LatLng> points;
  final double distanceKm; // actual road distance, not haversine
  final int durationMin;   // driving time at typical 30-50 km/h, per OSRM
  const _Route({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });
}

class ReferralMapWidget extends StatefulWidget {
  final String facilityType;
  final double mapHeight;
  final bool isEmergency; // RED band — markers turn red to signal urgency

  const ReferralMapWidget({
    super.key,
    required this.facilityType,
    this.mapHeight = 240,
    this.isEmergency = false,
  });

  @override
  State<ReferralMapWidget> createState() => _ReferralMapWidgetState();
}

class _ReferralMapWidgetState extends State<ReferralMapWidget> {
  final _mapController = MapController();

  Position? _userPos;
  List<_Place> _places = [];
  _Place? _selected;
  bool _loading = true;
  String? _error;

  /// Routed-path cache, keyed by Place. Populated lazily — only the
  /// currently-selected facility's route is fetched (and the previous
  /// selection's stays cached if the worker switches back). Avoids
  /// hammering OSRM with one request per place on map load.
  final Map<_Place, _Route> _routes = {};
  /// True while OSRM is in flight for the current selection; surfaces
  /// a faint "calculating route..." hint without blocking the map.
  bool _routingInFlight = false;

  static const _radii = [25000, 50000, 100000, 200000];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pos = await _getLocation();
      if (pos == null) return;
      List<_Place> places = [];
      for (final r in _radii) {
        places = await _fetchPlaces(pos, r);
        if (places.length >= 5) break;
      }
      if (!mounted) return;
      setState(() {
        _userPos = pos;
        _places = places;
        _selected = places.isNotEmpty ? places.first : null;
        _routes.clear();
        _loading = false;
      });
      // Kick off road-routing for the nearest place. Background fetch
      // so the map renders immediately with a straight line, then
      // upgrades to the actual road path when the route arrives.
      if (_selected != null) {
        unawaited(_ensureRoute(_selected!));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'ডেটা লোড হয়নি'; _loading = false; });
    }
  }

  /// Selects [place], moves the camera to fit it, and fetches the
  /// driving route from the user's position. Used by both the marker-
  /// tap and the list-tap paths so behaviour stays consistent.
  void _selectAndFitTo(_Place place) {
    setState(() => _selected = place);
    if (_userPos != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([
            LatLng(_userPos!.latitude, _userPos!.longitude),
            place.pos,
          ]),
          padding: const EdgeInsets.all(60),
        ),
      );
    }
    unawaited(_ensureRoute(place));
  }

  /// Fetches the OSRM road-route for [place] if not already cached and
  /// updates the polyline + distance/time chips. The public OSRM demo
  /// endpoint (router.project-osrm.org) is free, has no API key, and
  /// uses the same OpenStreetMap data we already render — so the
  /// polyline visually traces the same roads the worker can see on the
  /// map tiles. Falls back silently to the straight line on any
  /// error: missing route, OSRM down, slow rural network, etc.
  Future<void> _ensureRoute(_Place place) async {
    if (_routes.containsKey(place)) return;
    if (_userPos == null) return;
    setState(() => _routingInFlight = true);
    final route = await _fetchRoute(
      LatLng(_userPos!.latitude, _userPos!.longitude),
      place.pos,
    );
    if (!mounted) return;
    setState(() {
      if (route != null) _routes[place] = route;
      _routingInFlight = false;
    });
  }

  /// Resolution order:
  ///   1. Backend /api/directions — proxies Google Directions API,
  ///      live-traffic-aware, key stays server-side.
  ///   2. OSRM public — free, no key, OSM-based (no live traffic).
  ///   3. Null — caller draws the straight-line placeholder.
  ///
  /// Backend is tried first so a deployment with a Google Maps key
  /// gets the real-traffic numbers (and matching polyline), while a
  /// deployment without one falls through to OSRM automatically —
  /// no client-side config flag needed.
  Future<_Route?> _fetchRoute(LatLng origin, LatLng dest) async {
    final google = await _fetchGoogleRoute(origin, dest);
    if (google != null) return google;
    return _fetchOsrmRoute(origin, dest);
  }

  /// Backend proxy to Google Directions API (see server.js
  /// /api/directions). Returns null on any failure: not configured
  /// (503), no route (404), backend down, slow network, etc. The
  /// caller then tries OSRM.
  Future<_Route?> _fetchGoogleRoute(LatLng o, LatLng d) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/directions'
      '?olat=${o.latitude}&olng=${o.longitude}'
      '&dlat=${d.latitude}&dlng=${d.longitude}',
    );
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['success'] != true) return null;
      final raw = json['points'] as List?;
      if (raw == null || raw.isEmpty) return null;
      final pts = <LatLng>[];
      for (final pair in raw) {
        if (pair is List && pair.length >= 2) {
          final lat = (pair[0] as num).toDouble();
          final lng = (pair[1] as num).toDouble();
          pts.add(LatLng(lat, lng));
        }
      }
      if (pts.isEmpty) return null;
      final distM = (json['distanceM'] as num?)?.toDouble() ?? 0;
      // Prefer live-traffic duration if backend returned it.
      final durS = ((json['durationInTrafficS'] ?? json['durationS']) as num?)
              ?.toDouble() ??
          0;
      return _Route(
        points: pts,
        distanceKm: distM / 1000.0,
        durationMin: (durS / 60).round(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Public OSRM demo server — same OSM data we render on tiles, no
  /// key, no live traffic. Used as a fallback when the backend Google
  /// proxy isn't configured or unreachable.
  Future<_Route?> _fetchOsrmRoute(LatLng origin, LatLng dest) async {
    // OSRM coordinate order is lon,lat (not lat,lon).
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${dest.longitude},${dest.latitude}'
      '?overview=full&geometries=geojson',
    );
    try {
      final resp = await http
          .get(url, headers: {'User-Agent': 'AshamItraApp/1.0'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final r = routes.first as Map<String, dynamic>;
      final geom = (r['geometry'] as Map?)?['coordinates'] as List?;
      if (geom == null || geom.isEmpty) return null;
      final pts = <LatLng>[];
      for (final pair in geom) {
        if (pair is List && pair.length >= 2) {
          final lon = (pair[0] as num).toDouble();
          final lat = (pair[1] as num).toDouble();
          pts.add(LatLng(lat, lon));
        }
      }
      if (pts.isEmpty) return null;
      final distM = (r['distance'] as num?)?.toDouble() ?? 0;
      final durS = (r['duration'] as num?)?.toDouble() ?? 0;
      return _Route(
        points: pts,
        distanceKm: distM / 1000.0,
        durationMin: (durS / 60).round(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() { _error = 'GPS বন্ধ আছে। সেটিংস থেকে চালু করুন।'; _loading = false; });
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      if (mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('লোকেশন প্রয়োজন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: const Text('নিকটস্থ স্বাস্থ্যকেন্দ্র খুঁজে পেতে আপনার বর্তমান অবস্থান দরকার।', style: TextStyle(fontSize: 14)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('অনুমতি দিন', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        );
        if (proceed != true) {
          setState(() { _error = 'লোকেশন অনুমতি দেওয়া হয়নি'; _loading = false; });
          return null;
        }
      }
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      setState(() { _error = 'লোকেশন অনুমতি স্থায়ীভাবে বন্ধ।'; _loading = false; });
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('অনুমতি বন্ধ আছে', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: const Text('অ্যাপ সেটিংস থেকে লোকেশন অনুমতি চালু করুন।', style: TextStyle(fontSize: 14)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
              TextButton(
                onPressed: () { Navigator.pop(context); Geolocator.openAppSettings(); },
                child: const Text('সেটিংস খুলুন', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
      return null;
    }
    if (perm == LocationPermission.denied) {
      setState(() { _error = 'লোকেশন অনুমতি দেওয়া হয়নি'; _loading = false; });
      return null;
    }
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 60)),
      ).then((fresh) { if (mounted) setState(() => _userPos = fresh); }).catchError((_) {});
      return last;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 60)),
    );
  }

  Future<List<_Place>> _fetchPlaces(Position pos, int radius) async {
    final lat = pos.latitude;
    final lng = pos.longitude;
    final deg = radius / 111000.0;
    final viewbox = '${lng - deg},${lat + deg},${lng + deg},${lat - deg}';
    final headers = {'User-Agent': 'AshamItraApp/1.0 (health worker app India)'};

    final results = await Future.wait([
      _nominatimSearch('hospital', viewbox, headers),
      _nominatimSearch('clinic', viewbox, headers),
      _nominatimSearch('PHC primary health centre', viewbox, headers),
      _nominatimSearch('CHC community health centre', viewbox, headers),
      _nominatimSearch('district hospital', viewbox, headers),
      _nominatimSearch('SNCU newborn care', viewbox, headers),
    ]);

    final places = <_Place>[];
    for (final list in results) {
      for (final el in list) {
        final elLat = double.tryParse(el['lat']?.toString() ?? '');
        final elLng = double.tryParse(el['lon']?.toString() ?? '');
        if (elLat == null || elLng == null) continue;
        final dist = _distanceKm(lat, lng, elLat, elLng);
        final name = el['display_name']?.toString().split(',').first.trim()
            ?? el['name']?.toString() ?? 'Hospital';
        places.add(_Place(
          name: name,
          pos: LatLng(elLat, elLng),
          type: _classifyPlace(name),
          distanceKm: dist,
        ));
      }
    }

    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final seen = <String>{};
    return places.where((p) {
      final key = '${(p.pos.latitude * 500).round()},${(p.pos.longitude * 500).round()}';
      return seen.add(key);
    }).toList();
  }

  Future<List<dynamic>> _nominatimSearch(String q, String viewbox, Map<String, String> headers) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&q=${Uri.encodeComponent(q)}'
        '&bounded=1&viewbox=$viewbox&limit=20',
      );
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return [];
      return jsonDecode(resp.body) as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  static double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.pow(math.sin(dLng / 2), 2) *
        math.cos(lat1 * math.pi / 180) *
        math.cos(lat2 * math.pi / 180);
    return r * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }

  static String _extractFacilityKeyword(String raw) {
    final u = raw.toUpperCase();
    if (u.contains('SNCU')) return 'SNCU';
    if (u.contains('DH') || u.contains('DISTRICT')) return 'DH';
    if (u.contains('FRU')) return 'DH';
    if (u.contains('CHC') || u.contains('COMMUNITY')) return 'CHC';
    if (u.contains('PHC') || u.contains('PRIMARY')) return 'PHC';
    return 'hospital';
  }

  static String _classifyPlace(String name) {
    final n = name.toUpperCase();
    if (n.contains('SNCU') || n.contains('NEWBORN') || n.contains('NICU')) return 'SNCU';
    if (n.contains('DISTRICT') || n.contains(' DH') || n.contains('DISTRICT HOSPITAL')) return 'DH';
    if (n.contains('CHC') || n.contains('COMMUNITY HEALTH')) return 'CHC';
    if (n.contains('PHC') || n.contains('PRIMARY HEALTH') || n.contains('SUB CENTRE') || n.contains('SUBCENTRE')) return 'PHC';
    // Any hospital/clinic that doesn't match above is still a real hospital
    return 'hospital';
  }

  Color _colorForType(String type) {
    if (widget.isEmergency) return AppColors.emergencyRed;
    return switch (type) {
      'PHC'     => const Color(0xFF059669), // emerald green
      'CHC'     => const Color(0xFF0284C7), // sky blue
      'DH'      => const Color(0xFF7C3AED), // purple
      'SNCU'    => const Color(0xFFD97706), // amber
      'hospital'=> const Color(0xFF0F766E), // teal — general hospital (not red!)
      _         => const Color(0xFF0F766E),
    };
  }

  bool _isRecommended(String type) => _extractFacilityKeyword(widget.facilityType) == type;

  static String _typeLabelBn(String type) => switch (type) {
    'PHC'      => 'PHC — প্রাথমিক স্বাস্থ্য',
    'CHC'      => 'CHC — কমিউনিটি হেলথ',
    'DH'       => 'DH — জেলা হাসপাতাল',
    'SNCU'     => 'SNCU — নবজাতক যত্ন',
    'hospital' => 'হাসপাতাল / ক্লিনিক',
    _          => 'স্বাস্থ্যকেন্দ্র',
  };

  String _distanceLabel(double km) {
    if (km < 0.1) return '${(km * 1000).round()} মি';
    if (km < 10) return '${km.toStringAsFixed(1)} কিমি';
    return '${km.round()} কিমি';
  }

  /// Distance preferring the OSRM-routed value (real road distance)
  /// over the haversine straight-line. The two can differ by 30-80%
  /// in rural West Bengal where roads wind around fields, so the
  /// routed number is meaningfully more accurate for the worker.
  String _routedDistanceLabel(_Place p) {
    final r = _routes[p];
    if (r != null) return _distanceLabel(r.distanceKm);
    return _distanceLabel(p.distanceKm);
  }

  String _routedTravelTime(_Place p) {
    final r = _routes[p];
    if (r != null) {
      // OSRM's duration is computed from per-road speed limits — already
      // accounts for highway vs. village road. Just format it.
      final mins = r.durationMin;
      if (mins < 1) return '১ মিনিট';
      if (mins < 60) return '$mins মিনিট';
      final hrs = mins ~/ 60;
      final rem = mins % 60;
      return rem == 0 ? '$hrs ঘণ্টা' : '$hrs ঘণ্টা $rem মিনিট';
    }
    return _travelTime(p.distanceKm);
  }

  String _travelTime(double km) {
    if (km < 0.05) return '১ মিনিট';
    if (km < 2) {
      final mins = (km / 5 * 60).round();
      return '$mins মিনিট হাঁটা';
    }
    final mins = (km / 30 * 60).round();
    if (mins < 60) return '$mins মিনিট';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '$hrs ঘণ্টা' : '$hrs ঘণ্টা $rem মিনিট';
  }

  Future<void> _openDirections(_Place place) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${place.pos.latitude},${place.pos.longitude}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isEmergency
                    ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
                    : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                    widget.isEmergency ? Icons.emergency_rounded : Icons.local_hospital_rounded,
                    color: Colors.white, size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEmergency ? 'জরুরি রেফার কেন্দ্র' : 'নিকটস্থ রেফার কেন্দ্র',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        widget.isEmergency ? 'এখনই রেফার করুন — সময় নষ্ট করবেন না' : 'আপনার অবস্থান থেকে',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else
                  GestureDetector(
                    onTap: _init,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // ── Nearest facility summary bar ──────────────────────────────────
          if (!_loading && _error == null && _selected != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E7FF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _colorForType(_selected!.type),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selected!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B)),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _InfoChip(icon: Icons.straighten_rounded, label: _routedDistanceLabel(_selected!)),
                            _InfoChip(
                              icon: (_routes[_selected!]?.distanceKm ?? _selected!.distanceKm) < 2
                                  ? Icons.directions_walk_rounded
                                  : Icons.directions_car_rounded,
                              label: _routedTravelTime(_selected!),
                            ),
                            if (_routingInFlight && _routes[_selected!] == null)
                              const _InfoChip(
                                icon: Icons.route_rounded,
                                label: 'রাস্তা গণনা…',
                              ),
                            if (_selected!.isGovt)
                              _InfoChip(icon: Icons.verified_rounded, label: 'সরকারি', iconColor: const Color(0xFF059669)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openDirections(_selected!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: const Row(children: [
                        Icon(Icons.directions_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('পথ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // ── Map ───────────────────────────────────────────────────────────
          if (_loading)
            SizedBox(
              height: widget.mapHeight,
              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_error != null)
            _ErrorTile(error: _error!, onRetry: _init)
          else if (_userPos != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                height: widget.mapHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E7FF)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCameraFit: _selected != null
                              ? CameraFit.bounds(
                                  bounds: LatLngBounds.fromPoints([
                                    LatLng(_userPos!.latitude, _userPos!.longitude),
                                    _selected!.pos,
                                  ]),
                                  padding: const EdgeInsets.all(60),
                                )
                              : CameraFit.bounds(
                                  bounds: LatLngBounds.fromPoints([
                                    LatLng(_userPos!.latitude, _userPos!.longitude),
                                    LatLng(_userPos!.latitude + 0.01, _userPos!.longitude + 0.01),
                                  ]),
                                  padding: const EdgeInsets.all(60),
                                ),
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.ashamitra.app',
                          ),
                          if (_selected != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  // Use the routed road polyline when
                                  // available. Until the OSRM call
                                  // returns (~500-2000 ms) we still
                                  // render the dashed straight line as
                                  // a placeholder so the worker isn't
                                  // looking at an empty map.
                                  points: _routes[_selected!]?.points ??
                                      [
                                        LatLng(_userPos!.latitude,
                                            _userPos!.longitude),
                                        _selected!.pos,
                                      ],
                                  strokeWidth:
                                      _routes[_selected!] != null ? 4.5 : 3.5,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.85),
                                  pattern: _routes[_selected!] != null
                                      ? const StrokePattern.solid()
                                      : StrokePattern.dashed(
                                          segments: [12, 6]),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_userPos!.latitude, _userPos!.longitude),
                                width: 40, height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 10)],
                                  ),
                                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                              ..._places.map((p) {
                                final color = _colorForType(p.type);
                                final isSelected = _selected == p;
                                final recommended = _isRecommended(p.type);
                                return Marker(
                                  point: p.pos,
                                  width: isSelected ? 46 : (recommended ? 40 : 34),
                                  height: isSelected ? 46 : (recommended ? 40 : 34),
                                  child: GestureDetector(
                                    onTap: () => _selectAndFitTo(p),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected ? color : color.withValues(alpha: 0.85),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                          width: isSelected ? 3 : 2,
                                        ),
                                        boxShadow: [BoxShadow(
                                          color: color.withValues(alpha: isSelected ? 0.6 : 0.3),
                                          blurRadius: isSelected ? 14 : 6,
                                        )],
                                      ),
                                      child: Icon(
                                        Icons.local_hospital_rounded,
                                        color: Colors.white,
                                        size: isSelected ? 24 : (recommended ? 20 : 16),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                      // ── Dynamic legend overlay ───────────────────────────────────────
                      Positioned(
                        bottom: 8, left: 8,
                        child: _MapLegend(
                          // always show "You" entry
                          entries: [
                            _LegendEntry(color: AppColors.primary, icon: Icons.person_rounded, label: 'আপনি'),
                            // only show types that actually appear in _places
                            ..._places.map((p) => p.type).toSet().map((type) =>
                              _LegendEntry(
                                color: _colorForType(type),
                                icon: Icons.local_hospital_rounded,
                                label: _typeLabelBn(type),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Zoom + re-center controls ──────────────────────────────────────────────────
                      Positioned(
                        top: 8, right: 8,
                        child: Column(
                          children: [
                            _ZoomBtn(
                              icon: Icons.add_rounded,
                              onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                            ),
                            const SizedBox(height: 4),
                            _ZoomBtn(
                              icon: Icons.remove_rounded,
                              onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                            ),
                            const SizedBox(height: 4),
                            _ZoomBtn(
                              icon: Icons.my_location_rounded,
                              tooltip: 'ফিরে যান',
                              onTap: () {
                                if (_selected != null) {
                                  _mapController.fitCamera(
                                    CameraFit.bounds(
                                      bounds: LatLngBounds.fromPoints([
                                        LatLng(_userPos!.latitude, _userPos!.longitude),
                                        _selected!.pos,
                                      ]),
                                      padding: const EdgeInsets.all(60),
                                    ),
                                  );
                                } else {
                                  _mapController.move(
                                    LatLng(_userPos!.latitude, _userPos!.longitude), 14,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Zero results message ──────────────────────────────────────────
          if (!_loading && _error == null && _places.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '২০০ কিমির মধ্যে কোনো নিবন্ধিত স্বাস্থ্যকেন্দ্র পাওয়া যায়নি।',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // ── Facility list ─────────────────────────────────────────────────
          if (!_loading && _error == null && _places.isNotEmpty) ...[ 
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Text('কাছের কেন্দ্রসমূহ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onBackground)),
                  const Spacer(),
                  Text('${_places.length}টি পাওয়া গেছে',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ..._places.take(5).map((p) {
              final color = _colorForType(p.type);
              final isSelected = _selected == p;
              final recommended = _isRecommended(p.type);
              return GestureDetector(
                onTap: () => _selectAndFitTo(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color.withValues(alpha: 0.5) : const Color(0xFFE0E7FF),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? color : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${_places.indexOf(p) + 1}',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(p.name,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700,
                                      color: isSelected ? color : AppColors.onBackground,
                                    )),
                              ),
                              if (recommended) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('প্রস্তাবিত', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            // type chip
                            Row(children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(p.type, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              if (p.isGovt) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, size: 10, color: Color(0xFF059669)),
                                const SizedBox(width: 2),
                                const Text('সরকারি', style: TextStyle(fontSize: 9, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            // distance + time always on own row — never overflows.
                            // Routed values used when cached (selected row only —
                            // we don't pre-fetch routes for every list item, so
                            // unselected rows still show haversine).
                            Row(children: [
                              _InfoChip(icon: Icons.straighten_rounded, label: _routedDistanceLabel(p)),
                              const SizedBox(width: 6),
                              _InfoChip(
                                icon: (_routes[p]?.distanceKm ?? p.distanceKm) < 2
                                    ? Icons.directions_walk_rounded
                                    : Icons.directions_car_rounded,
                                label: _routedTravelTime(p),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openDirections(p),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.directions_rounded, color: color, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ── Info chip ────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  const _InfoChip({required this.icon, required this.label, this.iconColor = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: iconColor),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Legend entry model ────────────────────────────────────────────────────────────────
class _LegendEntry {
  final Color color;
  final IconData icon;
  final String label;
  const _LegendEntry({required this.color, required this.icon, required this.label});
}

// ── Dynamic map legend overlay ────────────────────────────────────────────────────────
class _MapLegend extends StatefulWidget {
  final List<_LegendEntry> entries;
  const _MapLegend({required this.entries});

  @override
  State<_MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<_MapLegend> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // toggle row
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('সংকেত', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B))),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                  size: 14, color: AppColors.primary,
                ),
              ],
            ),
          ),
          // entries — only shown when expanded
          if (_expanded) ...[
            const SizedBox(height: 4),
            ...widget.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
                    child: Icon(e.icon, size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(e.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF1E1B4B))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// ── Zoom button ───────────────────────────────────────────────────────────────────────────
class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _ZoomBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

// ── Error tile ────────────────────────────────────────────────────────────────
class _ErrorTile extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorTile({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD97706)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
          GestureDetector(
            onTap: onRetry,
            child: const Text('আবার চেষ্টা', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
