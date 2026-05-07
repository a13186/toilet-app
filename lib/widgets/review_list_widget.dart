import 'package:flutter/material.dart';
import '../services/rating_service.dart';

class ReviewListWidget extends StatefulWidget {
  final String toiletId;
  const ReviewListWidget({super.key, required this.toiletId});

  @override
  State<ReviewListWidget> createState() => _ReviewListWidgetState();
}

class _ReviewListWidgetState extends State<ReviewListWidget> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reviews = await RatingService.getReviews(widget.toiletId);
    if (mounted) setState(() { _reviews = reviews; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('아직 평가가 없습니다.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      );
    }
    return Column(
      children: _reviews.map((r) => _ReviewItem(r)).toList(),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewItem(this.review);

  @override
  Widget build(BuildContext context) {
    final stars = review['cleanliness'] as int? ?? 0;
    final comment = review['comment'] as String?;
    final hasBidet = review['has_bidet'] as bool?;
    final hasPaper = review['has_paper'] as bool?;
    final createdAt = review['created_at'] as String?;

    String? dateStr;
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        dateStr =
            '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  size: 14,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              if (hasBidet == true) ...[
                const Text('🚿', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
              ],
              if (hasPaper == true) ...[
                const Text('🧻', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              if (dateStr != null)
                Text(dateStr,
                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(comment, style: const TextStyle(fontSize: 13)),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }
}
