import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/toilet.dart';

class ToiletService {
  static final _client = Supabase.instance.client;

  static Future<List<Toilet>> getNearby({
    required double lat,
    required double lng,
    double radiusMeters = 1000,
    String? type,
  }) async {
    // 1차: PostGIS RPC 시도
    try {
      final res = await _client.rpc('get_nearby_toilets', params: {
        'lat': lat,
        'lng': lng,
        'radius_meters': radiusMeters.round(),
      });
      var list = (res as List).map((m) => Toilet.fromMap(m)).toList();
      if (list.isNotEmpty) {
        if (type != null && type != 'all') {
          list = list.where((t) => t.type == type).toList();
        }
        return list;
      }
    } catch (_) {}

    // 2차 폴백: location 컬럼 없어도 동작하는 좌표 박스 쿼리
    final deltaLat = radiusMeters / 111000;
    final deltaLng = radiusMeters / (111000 * cos(lat * pi / 180));

    final baseQuery = _client
        .from('toilets')
        .select()
        .gte('latitude', lat - deltaLat)
        .lte('latitude', lat + deltaLat)
        .gte('longitude', lng - deltaLng)
        .lte('longitude', lng + deltaLng);

    final res = await (type != null && type != 'all'
        ? baseQuery.eq('type', type).limit(100)
        : baseQuery.limit(100));
    var list = (res as List).map((m) => Toilet.fromMap(m)).toList();

    // 거리순 정렬
    list.sort((a, b) {
      final da = _dist(lat, lng, a.latitude, a.longitude);
      final db = _dist(lat, lng, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    return list;
  }

  static double _dist(double lat1, double lng1, double lat2, double lng2) {
    final dlat = lat2 - lat1;
    final dlng = lng2 - lng1;
    return sqrt(dlat * dlat + dlng * dlng);
  }

  static Future<Toilet?> getById(String id) async {
    final res =
        await _client.from('toilets').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Toilet.fromMap(res);
  }

  static Future<List<Toilet>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final res = await _client
        .from('toilets')
        .select()
        .inFilter('id', ids);
    return (res as List).map((m) => Toilet.fromMap(m)).toList();
  }

  static Future<List<Toilet>> searchByName(String query,
      {int limit = 10}) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _client
          .from('toilets')
          .select()
          .ilike('name', '%${query.trim()}%')
          .limit(limit);
      return (res as List).map((m) => Toilet.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }
}
