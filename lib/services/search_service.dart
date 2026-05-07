import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SearchResult {
  final String shortName;
  final String subTitle;
  final LatLng latlng;

  const SearchResult({
    required this.shortName,
    required this.subTitle,
    required this.latlng,
  });

  String get displayName => shortName;
}

class SearchService {
  static Map<String, String> get _headers =>
      kIsWeb ? {} : {'User-Agent': 'toilet_app/1.0'};

  static Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'countrycodes': 'kr',
      'limit': '5',
      'addressdetails': '1',
    });
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as List;
      return data.map((e) {
        final displayName = e['display_name'] as String;
        final addr = (e['address'] as Map?)?.cast<String, dynamic>() ?? {};
        return SearchResult(
          shortName: _extractShortName(displayName, addr),
          subTitle: _extractSubTitle(addr),
          latlng: LatLng(
            double.parse(e['lat'] as String),
            double.parse(e['lon'] as String),
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static String _extractShortName(
      String displayName, Map<String, dynamic> addr) {
    for (final key in [
      'amenity', 'shop', 'building', 'tourism', 'leisure', 'office'
    ]) {
      final v = addr[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return displayName.split(', ').first.trim();
  }

  static String _extractSubTitle(Map<String, dynamic> addr) {
    final parts = <String>[];
    for (final key in [
      'road', 'suburb', 'city_district', 'county', 'city', 'province'
    ]) {
      final v = addr[key];
      if (v is String && v.isNotEmpty && !parts.contains(v)) {
        parts.add(v);
        if (parts.length == 2) break;
      }
    }
    return parts.join(' · ');
  }
}
