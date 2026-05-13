import 'package:flutter/material.dart';
import '../models/toilet.dart';
import '../services/community_service.dart';

class ToiletListPanel extends StatefulWidget {
  final List<Toilet> toilets;
  final List<CommunityToilet> communityToilets;
  final ValueChanged<Toilet> onToiletTap;
  final ValueChanged<CommunityToilet> onCommunityToiletTap;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final double radiusMeters;
  final VoidCallback onRadiusTap;
  final bool hasExtraFilter;
  final int extraFilterCount;
  final VoidCallback onExtraFilterTap;

  const ToiletListPanel({
    super.key,
    required this.toilets,
    required this.communityToilets,
    required this.onToiletTap,
    required this.onCommunityToiletTap,
    required this.selectedType,
    required this.onTypeChanged,
    required this.radiusMeters,
    required this.onRadiusTap,
    required this.hasExtraFilter,
    required this.extraFilterCount,
    required this.onExtraFilterTap,
  });

  @override
  State<ToiletListPanel> createState() => _ToiletListPanelState();
}

class _ToiletListPanelState extends State<ToiletListPanel> {
  final _dsController = DraggableScrollableController();

  static const _minSize = 0.08;
  static const _maxSize = 0.65;
  static const _snapPoints = [0.15, 0.42, 0.65];

  bool get _isCommunityTab => widget.selectedType == 'community';

  int get _totalCount {
    if (_isCommunityTab) return widget.communityToilets.length;
    if (widget.selectedType == 'all') {
      return widget.toilets.length + widget.communityToilets.length;
    }
    return widget.toilets.length;
  }

  @override
  void dispose() {
    _dsController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dsController.isAttached) return;
    final screenH = MediaQuery.of(context).size.height;
    final delta = -(d.primaryDelta ?? 0) / screenH;
    _dsController.jumpTo(
      (_dsController.size + delta).clamp(_minSize, _maxSize),
    );
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dsController.isAttached) return;
    final size = _dsController.size;
    final velocity = d.primaryVelocity ?? 0;

    double target;
    if (velocity < -400) {
      target = 0.65;
    } else if (velocity > 400) {
      target = 0.15;
    } else {
      target = _snapPoints.reduce(
        (a, b) => (a - size).abs() < (b - size).abs() ? a : b,
      );
    }
    _dsController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _onHeaderTap() {
    if (!_dsController.isAttached) return;
    final target = _dsController.size <= 0.16 ? 0.42 : 0.15;
    _dsController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  static const _typeFilters = [
    ('all', '전체'),
    ('public', '공중'),
    ('dev', '개발'),
    ('community', '커뮤니티'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return DraggableScrollableSheet(
      controller: _dsController,
      initialChildSize: 0.15,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: _snapPoints,
      builder: (_, scrollController) => DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black26,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 헤더
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              onTap: _onHeaderTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          '내 주변 화장실',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_totalCount개',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        AnimatedBuilder(
                          animation: _dsController,
                          builder: (context2, _) {
                            final isOpen = _dsController.isAttached &&
                                _dsController.size > 0.16;
                            return Icon(
                              isOpen
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              size: 20,
                              color: Colors.grey[500],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._typeFilters.map((e) {
                          final selected = widget.selectedType == e.$1;
                          return ChoiceChip(
                            label: Text(e.$2),
                            selected: selected,
                            onSelected: (_) =>
                                widget.onTypeChanged(e.$1),
                            visualDensity: VisualDensity.standard,
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }),
                        if (!_isCommunityTab)
                          ActionChip(
                            backgroundColor: widget.hasExtraFilter
                                ? colorScheme.primaryContainer
                                : null,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune,
                                    size: 14,
                                    color: widget.hasExtraFilter
                                        ? colorScheme.primary
                                        : null),
                                const SizedBox(width: 4),
                                Text(
                                  '필터',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: widget.hasExtraFilter
                                        ? colorScheme.primary
                                        : null,
                                  ),
                                ),
                                if (widget.hasExtraFilter) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${widget.extraFilterCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onPressed: widget.onExtraFilterTap,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                ],
              ),
            ),
            // 목록
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: _buildListContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent() {
    if (_totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 52, color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text('주변에 화장실이 없습니다.',
                  style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text('반경을 넓히거나 지도를 이동해보세요.',
                  style:
                      TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_isCommunityTab) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.communityToilets.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, idx) => _CommunityToiletListItem(
          toilet: widget.communityToilets[idx],
          onTap: () =>
              widget.onCommunityToiletTap(widget.communityToilets[idx]),
        ),
      );
    }

    if (widget.selectedType != 'all') {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.toilets.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, idx) => _ToiletListItem(
          toilet: widget.toilets[idx],
          onTap: () => widget.onToiletTap(widget.toilets[idx]),
        ),
      );
    }

    return Column(
      children: [
        ..._buildAllList(),
      ],
    );
  }

  List<Widget> _buildAllList() {
    final items = <Widget>[];
    final officialCount = widget.toilets.length;
    final communityCount = widget.communityToilets.length;

    for (int i = 0; i < officialCount; i++) {
      items.add(_ToiletListItem(
        toilet: widget.toilets[i],
        onTap: () => widget.onToiletTap(widget.toilets[i]),
      ));
      if (i < officialCount - 1) {
        items.add(const Divider(height: 1, indent: 72));
      }
    }

    if (communityCount > 0) {
      if (officialCount > 0) {
        items.add(const Divider(height: 1, indent: 72));
      }
      items.add(_SectionHeader(
        label: '커뮤니티 화장실',
        color: Colors.purple.shade400,
      ));
      for (int i = 0; i < communityCount; i++) {
        items.add(_CommunityToiletListItem(
          toilet: widget.communityToilets[i],
          onTap: () =>
              widget.onCommunityToiletTap(widget.communityToilets[i]),
        ));
        if (i < communityCount - 1) {
          items.add(const Divider(height: 1, indent: 72));
        }
      }
    }

    return items;
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToiletListItem extends StatelessWidget {
  final Toilet toilet;
  final VoidCallback onTap;
  const _ToiletListItem({required this.toilet, required this.onTap});

  Color _typeColor(String type) => switch (type) {
        'public' => Colors.blue,
        'open' => Colors.green,
        'simple' => Colors.orange,
        'mobile' => Colors.purple,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _typeColor(toilet.type).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🚽', style: TextStyle(fontSize: 20)),
        ),
      ),
      title: Text(
        toilet.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        toilet.roadAddress ?? toilet.address ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (toilet.distanceMeters != null)
            Text(
              toilet.distanceLabel,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          if (toilet.avgCleanliness != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 12, color: Colors.amber),
                Text(
                  toilet.avgCleanliness!.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityToiletListItem extends StatelessWidget {
  final CommunityToilet toilet;
  final VoidCallback onTap;
  const _CommunityToiletListItem(
      {required this.toilet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(toilet.placeTypeEmoji,
              style: const TextStyle(fontSize: 20)),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              toilet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              toilet.placeTypeLabel,
              style: TextStyle(fontSize: 10, color: Colors.purple[700]),
            ),
          ),
        ],
      ),
      subtitle: toilet.address != null && toilet.address!.isNotEmpty
          ? Text(
              toilet.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: toilet.reviewCount > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 12, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Text(
                  '${toilet.reviewCount}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            )
          : null,
    );
  }
}
