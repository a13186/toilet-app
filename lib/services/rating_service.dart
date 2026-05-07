import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_service.dart';

class RatingService {
  static final _db = Supabase.instance.client;

  static Future<void> submit({
    required String toiletId,
    required int cleanliness,
    bool? hasBidet,
    bool? hasPaper,
    String? comment,
  }) async {
    final deviceId = await DeviceService.getId();
    await _db.rpc('submit_rating', params: {
      'p_toilet_id': toiletId,
      'p_device_id': deviceId,
      'p_cleanliness': cleanliness,
      'p_has_bidet': hasBidet,
      'p_has_paper': hasPaper,
      'p_comment': (comment != null && comment.isNotEmpty) ? comment : null,
    });
  }

  static Future<List<Map<String, dynamic>>> getReviews(String toiletId) async {
    try {
      final res = await _db
          .from('ratings')
          .select('cleanliness, has_bidet, has_paper, comment, created_at')
          .eq('toilet_id', toiletId)
          .order('created_at', ascending: false)
          .limit(20);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
