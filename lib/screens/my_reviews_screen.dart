import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/device_service.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _ReviewItem {
  final bool isOfficial;
  final String toiletName;
  final double? rating;
  final String? comment;
  final DateTime createdAt;

  const _ReviewItem({
    required this.isOfficial,
    required this.toiletName,
    this.rating,
    this.comment,
    required this.createdAt,
  });
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  List<_ReviewItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final deviceId = await DeviceService.getId();
    final db = Supabase.instance.client;

    try {
      final results = await Future.wait([
        db
            .from('toilet_ratings')
            .select('cleanliness, comment, created_at, toilets(name)')
            .eq('device_id', deviceId)
            .order('created_at', ascending: false),
        db
            .from('community_reviews')
            .select('rating, created_at, community_toilets(name)')
            .eq('device_id', deviceId)
            .order('created_at', ascending: false),
      ]);

      final items = <_ReviewItem>[];

      for (final r in (results[0] as List)) {
        final m = r as Map<String, dynamic>;
        items.add(_ReviewItem(
          isOfficial: true,
          toiletName:
              (m['toilets'] as Map<String, dynamic>?)?['name'] as String? ??
                  '화장실',
          rating: (m['cleanliness'] as num?)?.toDouble(),
          comment: m['comment'] as String?,
          createdAt:
              DateTime.tryParse(m['created_at'] as String? ?? '') ??
                  DateTime.now(),
        ));
      }

      for (final r in (results[1] as List)) {
        final m = r as Map<String, dynamic>;
        final ratingVal = m['rating'];
        items.add(_ReviewItem(
          isOfficial: false,
          toiletName:
              (m['community_toilets'] as Map<String, dynamic>?)?['name']
                      as String? ??
                  '커뮤니티 화장실',
          rating: ratingVal != null ? (ratingVal as num).toDouble() : null,
          comment: null,
          createdAt:
              DateTime.tryParse(m['created_at'] as String? ?? '') ??
                  DateTime.now(),
        ));
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내가 쓴 평가/후기')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('작성한 평가나 후기가 없습니다.',
                          style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text('지도에서 화장실을 탭해 평가를 남겨보세요.',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (context, i) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) => _ReviewTile(_items[i]),
                ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final _ReviewItem item;
  const _ReviewTile(this.item);

  String get _dateLabel {
    final now = DateTime.now();
    final diff = now.difference(item.createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    final d = item.createdAt;
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = item.isOfficial ? Colors.blue : Colors.purple;
    final rating = item.rating;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.isOfficial ? '공식 화장실' : '커뮤니티',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.toiletName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(_dateLabel,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
          if (rating != null) ...[
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < rating.round() ? Icons.star : Icons.star_border,
                  size: 16,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.comment!,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ],
      ),
    );
  }
}
