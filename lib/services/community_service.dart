import 'dart:math' show cos, pi;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_service.dart';

/*
  ═══════════════════════════════════════════════════════════════════
  Supabase → SQL Editor에서 아래 SQL을 1회 실행하세요.
  ═══════════════════════════════════════════════════════════════════

  CREATE TABLE community_toilets (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name         TEXT        NOT NULL,
    address      TEXT,
    place_type   TEXT        NOT NULL DEFAULT 'etc',
    description  TEXT,
    device_id    TEXT        NOT NULL,
    latitude     FLOAT8,
    longitude    FLOAT8,
    osm_id       TEXT        UNIQUE,    -- NULL=사용자등록, "node/xxx"=OSM 임포트
    created_at   TIMESTAMPTZ DEFAULT NOW()
  );

  -- 기존 테이블에 컬럼 추가하는 경우:
  -- ALTER TABLE community_toilets ADD COLUMN IF NOT EXISTS osm_id TEXT UNIQUE;
  --
  -- 기존 OSM 중복 데이터 정리 후 unique 인덱스 추가:
  -- DELETE FROM community_toilets
  --   WHERE device_id = 'osm_import_v1'
  --   AND id NOT IN (
  --     SELECT MIN(id) FROM community_toilets
  --     WHERE device_id = 'osm_import_v1'
  --     GROUP BY name, latitude, longitude
  --   );
  -- CREATE UNIQUE INDEX IF NOT EXISTS idx_community_osm_id
  --   ON community_toilets (osm_id) WHERE osm_id IS NOT NULL;

  CREATE TABLE community_reviews (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    toilet_id   UUID        NOT NULL REFERENCES community_toilets(id) ON DELETE CASCADE,
    device_id   TEXT        NOT NULL,
    comment     TEXT,
    password    TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
  );

  ALTER TABLE community_toilets ENABLE ROW LEVEL SECURITY;
  ALTER TABLE community_reviews  ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "public_read"   ON community_toilets FOR SELECT USING (true);
  CREATE POLICY "public_insert" ON community_toilets FOR INSERT WITH CHECK (true);
  CREATE POLICY "public_read"   ON community_reviews  FOR SELECT USING (true);
  CREATE POLICY "public_insert" ON community_reviews  FOR INSERT WITH CHECK (true);
  ═══════════════════════════════════════════════════════════════════
*/

// ── 모델 ──────────────────────────────────────────────────────────

class CommunityToilet {
  final String id;
  final String name;
  final String? address;
  final String placeType;
  final String? description;
  final String deviceId;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final int reviewCount;
  final double? avgRating;
  final int ratingCount;

  const CommunityToilet({
    required this.id,
    required this.name,
    this.address,
    required this.placeType,
    this.description,
    required this.deviceId,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.reviewCount = 0,
    this.avgRating,
    this.ratingCount = 0,
  });

  factory CommunityToilet.fromMap(Map<String, dynamic> m) {
    final reviews = (m['community_reviews'] as List?)
            ?.cast<Map<String, dynamic>>()
            .toList() ??
        [];
    reviews.sort((a, b) =>
        (b['created_at'] as String).compareTo(a['created_at'] as String));

    final rated = reviews
        .where((r) => r['rating'] != null)
        .map((r) => (r['rating'] as num).toDouble())
        .toList();
    final avgRating = rated.isEmpty
        ? null
        : rated.reduce((a, b) => a + b) / rated.length;

    return CommunityToilet(
      id: m['id'] as String,
      name: m['name'] as String,
      address: m['address'] as String?,
      placeType: m['place_type'] as String? ?? 'etc',
      description: m['description'] as String?,
      deviceId: m['device_id'] as String,
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      reviewCount: reviews.length,
      avgRating: avgRating,
      ratingCount: rated.length,
    );
  }

  String get placeTypeLabel => switch (placeType) {
        'cafe' => '카페',
        'restaurant' => '음식점',
        'convenience' => '편의점',
        'building' => '빌딩·사무실',
        _ => '기타',
      };

  String get placeTypeEmoji => switch (placeType) {
        'cafe' => '☕',
        'restaurant' => '🍽️',
        'convenience' => '🏪',
        'building' => '🏢',
        _ => '🚪',
      };
}

class CommunityReview {
  final String id;
  final String toiletId;
  final String deviceId;
  final String? password;
  final int? rating;
  final DateTime createdAt;

  const CommunityReview({
    required this.id,
    required this.toiletId,
    required this.deviceId,
    this.password,
    this.rating,
    required this.createdAt,
  });

  factory CommunityReview.fromMap(Map<String, dynamic> m) => CommunityReview(
        id: m['id'] as String,
        toiletId: m['toilet_id'] as String,
        deviceId: m['device_id'] as String,
        password: m['password'] as String?,
        rating: m['rating'] as int?,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  String get dateLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}';
  }
}

// ── 서비스 ────────────────────────────────────────────────────────

class CommunityService {
  static final _db = Supabase.instance.client;

  static Future<List<CommunityToilet>> getToilets({
    String? placeType,
    double? lat,
    double? lng,
    double radiusMeters = 1000,
  }) async {
    try {
      List<dynamic> res;
      if (lat != null && lng != null) {
        final deltaLat = radiusMeters / 111000;
        final deltaLng = radiusMeters / (111000 * cos(lat * pi / 180));
        res = await _db
            .from('community_toilets')
            .select('*, community_reviews(id, rating, password, created_at)')
            .gte('latitude', lat - deltaLat)
            .lte('latitude', lat + deltaLat)
            .gte('longitude', lng - deltaLng)
            .lte('longitude', lng + deltaLng)
            .order('created_at', ascending: false)
            .limit(300);
      } else {
        res = await _db
            .from('community_toilets')
            .select('*, community_reviews(id, rating, password, created_at)')
            .order('created_at', ascending: false)
            .limit(300);
      }

      var list = res
          .cast<Map<String, dynamic>>()
          .map(CommunityToilet.fromMap)
          .toList();

      if (placeType != null && placeType != 'all') {
        list = list.where((t) => t.placeType == placeType).toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<List<CommunityReview>> getReviews(String toiletId) async {
    try {
      final res = await _db
          .from('community_reviews')
          .select()
          .eq('toilet_id', toiletId)
          .order('created_at', ascending: false);
      return (res as List)
          .cast<Map<String, dynamic>>()
          .map(CommunityReview.fromMap)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addToilet({
    required String name,
    String? address,
    required String placeType,
    String? description,
    double? latitude,
    double? longitude,
  }) async {
    final deviceId = await DeviceService.getId();
    await _db.from('community_toilets').insert({
      'name': name,
      'address': (address != null && address.isNotEmpty) ? address : null,
      'place_type': placeType,
      'description':
          (description != null && description.isNotEmpty) ? description : null,
      'device_id': deviceId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  static Future<void> addRating({
    required String toiletId,
    required int rating,
  }) async {
    final deviceId = await DeviceService.getId();
    await _db.from('community_reviews').insert({
      'toilet_id': toiletId,
      'device_id': deviceId,
      'rating': rating,
    });
  }

  static Future<void> addPassword({
    required String toiletId,
    required String password,
  }) async {
    final deviceId = await DeviceService.getId();
    await _db.from('community_reviews').insert({
      'toilet_id': toiletId,
      'device_id': deviceId,
      'password': password,
    });
  }

  static Future<List<CommunityToilet>> searchByName(String query,
      {int limit = 10}) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _db
          .from('community_toilets')
          .select('*, community_reviews(id, rating, password, created_at)')
          .ilike('name', '%${query.trim()}%')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .limit(limit);
      return (res as List)
          .cast<Map<String, dynamic>>()
          .map(CommunityToilet.fromMap)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
