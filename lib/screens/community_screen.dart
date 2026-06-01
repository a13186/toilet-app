import 'package:flutter/material.dart';

import '../services/community_service.dart';
import 'community_detail_screen.dart';
import 'add_community_toilet_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const _typeFilters = [
    ('all', '전체'),
    ('cafe', '카페'),
    ('restaurant', '음식점'),
    ('convenience', '편의점'),
    ('building', '빌딩'),
    ('etc', '기타'),
  ];

  String _selectedType = 'all';
  List<CommunityToilet> _toilets = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await CommunityService.getToilets(
      placeType: _selectedType == 'all' ? null : _selectedType,
    );
    if (mounted) setState(() { _toilets = list; _loading = false; });
  }

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddCommunityToiletScreen()),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Text(
                    '커뮤니티 화장실',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (!_loading)
                    Text(
                      '${_toilets.length}개',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '새로고침',
                    onPressed: _load,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '  사용자가 직접 등록한 화장실 정보입니다',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),

            // ── 유형 필터 칩 ───────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _typeFilters.map((e) {
                  final selected = _selectedType == e.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(e.$2),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedType = e.$1);
                        _load();
                      },
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),

            // ── 목록 ───────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _toilets.isEmpty
                      ? _EmptyState(onAdd: _openAdd)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _toilets.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 72),
                            itemBuilder: (_, i) => _CommunityToiletTile(
                              toilet: _toilets[i],
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CommunityDetailScreen(
                                        toilet: _toilets[i]),
                                  ),
                                );
                                _load();
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('화장실 등록'),
      ),
    );
  }
}

// ── 빈 상태 ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wc_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('등록된 화장실이 없습니다.',
              style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 6),
          Text('첫 번째 화장실을 등록해 보세요!',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('화장실 등록'),
          ),
        ],
      ),
    );
  }
}

// ── 목록 아이템 ──────────────────────────────────────────────────────

class _CommunityToiletTile extends StatelessWidget {
  final CommunityToilet toilet;
  final VoidCallback onTap;
  const _CommunityToiletTile({required this.toilet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            toilet.placeTypeEmoji,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              toilet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              toilet.placeTypeLabel,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (toilet.address != null && toilet.address!.isNotEmpty)
            Text(
              toilet.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            )
          else if (toilet.latitude != null && toilet.longitude != null)
            Text(
              '📍 ${toilet.latitude!.toStringAsFixed(5)}, ${toilet.longitude!.toStringAsFixed(5)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          if (toilet.avgRating != null)
            Text(
              '⭐ ${toilet.avgRating!.toStringAsFixed(1)} (${toilet.ratingCount}명)',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 13, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Text(
                '${toilet.reviewCount}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
