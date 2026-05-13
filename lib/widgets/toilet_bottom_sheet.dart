import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/toilet.dart';
import '../services/favorites_service.dart';
import '../services/history_service.dart';
import '../services/navigation_service.dart';
import 'rating_sheet.dart';
import 'review_list_widget.dart';

class ToiletBottomSheet extends StatefulWidget {
  final Toilet toilet;
  final VoidCallback? onFavoriteToggled;
  const ToiletBottomSheet({
    super.key,
    required this.toilet,
    this.onFavoriteToggled,
  });

  @override
  State<ToiletBottomSheet> createState() => _ToiletBottomSheetState();
}

class _ToiletBottomSheetState extends State<ToiletBottomSheet> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    FavoritesService.isFavorite(widget.toilet.id).then((v) {
      if (mounted) setState(() => _isFavorite = v);
    });
    // 최근 본 화장실 기록
    HistoryService.add(widget.toilet.id);
  }

  Future<void> _toggleFavorite() async {
    final added = await FavoritesService.toggle(widget.toilet.id);
    if (mounted) setState(() => _isFavorite = added);
    widget.onFavoriteToggled?.call();
  }

  void _share() {
    final t = widget.toilet;
    final address = t.roadAddress ?? t.address ?? '';
    SharePlus.instance.share(ShareParams(
      text: '🚽 ${t.name}\n'
          '📍 $address\n'
          '지도: https://maps.google.com/?q=${t.latitude},${t.longitude}',
    ));
  }

  void _openNavigation() {
    final t = widget.toilet;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('길 안내 앱 선택',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Text('🗺️', style: TextStyle(fontSize: 22)),
              title: const Text('구글 지도'),
              onTap: () {
                Navigator.pop(context);
                NavigationService.openGoogleMaps(t.latitude, t.longitude);
              },
            ),
            ListTile(
              leading: const Text('🟡', style: TextStyle(fontSize: 22)),
              title: const Text('카카오맵'),
              onTap: () {
                Navigator.pop(context);
                NavigationService.openKakaoMap(
                    t.latitude, t.longitude, t.name);
              },
            ),
            ListTile(
              leading: const Text('🟢', style: TextStyle(fontSize: 22)),
              title: const Text('네이버 지도'),
              onTap: () {
                Navigator.pop(context);
                NavigationService.openNaverMap(
                    t.latitude, t.longitude, t.name, 'com.example.toilet_app');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRating() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingSheet(toilet: widget.toilet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toilet = widget.toilet;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // 핸들 바
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // 이름 + 거리 + 공유 + 즐겨찾기
            Row(
              children: [
                Expanded(
                  child: Text(toilet.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (toilet.distanceMeters != null)
                  Text(toilet.distanceLabel,
                      style: const TextStyle(color: Colors.grey)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 22),
                  onPressed: _share,
                  visualDensity: VisualDensity.compact,
                  tooltip: '공유',
                ),
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: _toggleFavorite,
                  visualDensity: VisualDensity.compact,
                  tooltip: '즐겨찾기',
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 유형 + 유료 뱃지
            Row(
              children: [
                _TypeChip(toilet.typeLabel),
                if (toilet.isPaid) ...[
                  const SizedBox(width: 6),
                  _TypeChip('유료', color: Colors.orange),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // 주소 / 시간 / 전화
            if (toilet.roadAddress != null)
              _InfoRow(Icons.location_on, toilet.roadAddress!),
            if (toilet.openTime != null)
              _InfoRow(Icons.access_time, toilet.openTime!),
            if (toilet.openTimeDetail != null)
              _InfoRow(Icons.info_outline, toilet.openTimeDetail!),
            if (toilet.managementTel != null)
              _InfoRow(Icons.phone, toilet.managementTel!),
            const Divider(height: 24),
            // 시설 그리드
            _FacilityGrid(toilet),
            // 평점
            if (toilet.avgCleanliness != null) ...[
              const Divider(height: 24),
              _RatingRow(toilet),
            ],
            const SizedBox(height: 20),
            // 액션 버튼 (평가 / 길 안내)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showRating,
                    icon: const Icon(Icons.star_border, size: 18),
                    label: const Text('평가 · 후기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openNavigation,
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('길 안내'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 리뷰 섹션
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Text('방문 후기',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showRating,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('후기 쓰기',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero),
                  ),
                ],
              ),
            ),
            ReviewListWidget(toiletId: toilet.id),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeChip(this.label, {this.color = Colors.blue});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
                child:
                    Text(text, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );
}

class _FacilityGrid extends StatelessWidget {
  final Toilet t;
  const _FacilityGrid(this.t);

  @override
  Widget build(BuildContext context) {
    final items = [
      ('남성 대변기', '${t.maleToilets}'),
      ('남성 소변기', '${t.maleUrinals}'),
      ('여성 대변기', '${t.femaleToilets}'),
      ('장애인(남)', '${t.disabledMaleToilets}'),
      ('장애인(여)', '${t.disabledFemaleToilets}'),
      if (t.babyChangingMale == true || t.babyChangingFemale == true)
        ('기저귀교환대', '있음'),
      if (t.emergencyBell == true) ('비상벨', '있음'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items
          .map((e) => _FacilityItem(label: e.$1, value: e.$2))
          .toList(),
    );
  }
}

class _FacilityItem extends StatelessWidget {
  final String label;
  final String value;
  const _FacilityItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _RatingRow extends StatelessWidget {
  final Toilet t;
  const _RatingRow(this.t);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.star, size: 18, color: Colors.amber),
          const SizedBox(width: 4),
          Text(t.avgCleanliness!.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(' (${t.ratingCount}명 평가)',
              style:
                  const TextStyle(color: Colors.grey, fontSize: 13)),
          if (t.hasBidet == true) ...[
            const SizedBox(width: 12),
            const Text('🚿 비데', style: TextStyle(fontSize: 13)),
          ],
          if (t.hasPaper == true) ...[
            const SizedBox(width: 8),
            const Text('🧻 화장지', style: TextStyle(fontSize: 13)),
          ],
        ],
      );
}
