import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

enum LocationError {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  unknown,
}

class LocationResult {
  final double? lat;
  final double? lng;
  final LocationError? error;
  final bool fromIp; // GPS vs IP 기반 여부

  const LocationResult.ok(this.lat, this.lng, {this.fromIp = false})
      : error = null;
  const LocationResult.fail(this.error)
      : lat = null,
        lng = null,
        fromIp = false;

  bool get isOk => lat != null && lng != null;
}

class LocationService {
  static Future<LocationResult> getCurrentPosition() async {
    // ── 1차: GPS ──────────────────────────────────────────────
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          return LocationResult.ok(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}

    // ── 2차 폴백: 마지막 알려진 위치 ──────────────────────────
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationResult.ok(last.latitude, last.longitude);
      }
    } catch (_) {}

    // ── 3차 폴백: IP 기반 위치 ────────────────────────────────
    return _getLocationFromIp();
  }

  static Future<LocationResult> _getLocationFromIp() async {
    // 1순위: ipapi.co (HTTPS 무료)
    try {
      final res = await http
          .get(Uri.parse('https://ipapi.co/json/'),
              headers: {'User-Agent': 'toilet_app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final lat = data['latitude'];
        final lng = data['longitude'];
        if (lat != null && lng != null) {
          return LocationResult.ok(
              (lat as num).toDouble(), (lng as num).toDouble(),
              fromIp: true);
        }
      }
    } catch (_) {}

    // 2순위: freeipapi.com (HTTPS 무료)
    try {
      final res = await http
          .get(Uri.parse('https://freeipapi.com/api/json'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final lat = data['latitude'];
        final lng = data['longitude'];
        if (lat != null && lng != null) {
          return LocationResult.ok(
              (lat as num).toDouble(), (lng as num).toDouble(),
              fromIp: true);
        }
      }
    } catch (_) {}

    return const LocationResult.fail(LocationError.unknown);
  }

  static Stream<Position> getPositionStream({int distanceFilterMeters = 300}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }
}
