import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/toilet.dart';
import '../services/community_service.dart';
import '../services/recent_search_service.dart';
import '../services/search_service.dart';
import '../services/toilet_service.dart';

// ── 검색 결과 선택 모델 ────────────────────────────────────────────────

class SearchSelection {
  final LatLng latlng;
  final Toilet? toilet;
  final CommunityToilet? communityToilet;

  const SearchSelection({
    required this.latlng,
    this.toilet,
    this.communityToilet,
  });
}

// ── 검색 화면 ─────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<Toilet> _toiletResults = [];
  List<CommunityToilet> _communityResults = [];
  List<SearchResult> _placeResults = [];
  List<String> _recentSearches = [];
  bool _searching = false;

  bool get _hasQuery => _ctrl.text.trim().isNotEmpty;
  bool get _hasResults =>
      _toiletResults.isNotEmpty ||
      _communityResults.isNotEmpty ||
      _placeResults.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final list = await RecentSearchService.getAll();
    if (mounted) setState(() => _recentSearches = list);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _toiletResults = [];
        _communityResults = [];
        _placeResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _doSearch(value));
  }

  Future<void> _doSearch(String query) async {
    if (!mounted || query.trim().isEmpty) return;
    final results = await Future.wait([
      ToiletService.searchByName(query),
      CommunityService.searchByName(query),
      SearchService.search(query),
    ]);
    if (!mounted) return;
    setState(() {
      _toiletResults = results[0] as List<Toilet>;
      _communityResults = results[1] as List<CommunityToilet>;
      _placeResults = results[2] as List<SearchResult>;
      _searching = false;
    });
  }

  Future<void> _select(SearchSelection selection, String keyword) async {
    await RecentSearchService.add(keyword);
    if (mounted) Navigator.of(context).pop(selection);
  }

  void _selectToilet(Toilet t) => _select(
        SearchSelection(
            latlng: LatLng(t.latitude, t.longitude), toilet: t),
        t.name,
      );

  void _selectCommunity(CommunityToilet t) {
    if (t.latitude == null || t.longitude == null) return;
    _select(
      SearchSelection(
          latlng: LatLng(t.latitude!, t.longitude!), communityToilet: t),
      t.name,
    );
  }

  void _selectPlace(SearchResult r) => _select(
        SearchSelection(latlng: r.latlng),
        _ctrl.text.trim(),
      );

  void _selectRecent(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _searching = true);
    _debounce?.cancel();
    _doSearch(q);
  }

  Future<void> _removeRecent(String q) async {
    await RecentSearchService.remove(q);
    _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          decoration: InputDecoration(
            hintText: '화장실 이름 또는 장소 검색',
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (q) {
            _debounce?.cancel();
            if (q.trim().isNotEmpty) {
              setState(() => _searching = true);
              _doSearch(q);
            }
          },
        ),
        actions: [
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: !_hasQuery
          ? _buildRecent()
          : (_hasResults || _searching)
              ? _buildResults()
              : _buildEmpty(),
    );
  }

  // ── 최근 검색어 ────────────────────────────────────────────────────

  Widget _buildRecent() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('화장실 이름이나 장소를 검색하세요',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Text(
                '최근 검색',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600]),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await RecentSearchService.clear();
                  setState(() => _recentSearches = []);
                },
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero),
                child: const Text('전체 삭제',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        ..._recentSearches.map(
          (q) => ListTile(
            leading:
                const Icon(Icons.history, size: 20, color: Colors.grey),
            title: Text(q, style: const TextStyle(fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _removeRecent(q),
            ),
            onTap: () => _selectRecent(q),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── 검색 결과 ──────────────────────────────────────────────────────

  Widget _buildResults() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_toiletResults.isNotEmpty) ...[
          _SectionHeader(
              label: '공식 화장실',
              icon: Icons.wc_rounded,
              color: Colors.blue),
          ..._toiletResults.map((t) => _ToiletTile(
                name: t.name,
                sub: t.roadAddress ?? t.address ?? t.typeLabel,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                      child: Text('🚽',
                          style: TextStyle(fontSize: 18))),
                ),
                trailing: t.distanceMeters != null
                    ? Text(t.distanceLabel,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]))
                    : null,
                onTap: () => _selectToilet(t),
              )),
          const Divider(height: 1),
        ],
        if (_communityResults.isNotEmpty) ...[
          _SectionHeader(
              label: '커뮤니티 화장실',
              icon: Icons.people_outline,
              color: Colors.purple),
          ..._communityResults.map((t) => _ToiletTile(
                name: t.name,
                sub: t.address ?? t.placeTypeLabel,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                      child: Text(t.placeTypeEmoji,
                          style: const TextStyle(fontSize: 18))),
                ),
                onTap: () => _selectCommunity(t),
              )),
          const Divider(height: 1),
        ],
        if (_placeResults.isNotEmpty) ...[
          _SectionHeader(
              label: '장소',
              icon: Icons.location_on_outlined,
              color: Colors.grey.shade600),
          ..._placeResults.map((r) => _ToiletTile(
                name: r.shortName,
                sub: r.subTitle,
                leading: Icon(Icons.location_on_outlined,
                    size: 28, color: Colors.grey[500]),
                onTap: () => _selectPlace(r),
              )),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ── 결과 없음 ──────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('"${_ctrl.text.trim()}" 검색 결과가 없습니다',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 4),
          Text('다른 검색어를 입력해보세요',
              style:
                  TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }
}

// ── 공통 위젯 ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SectionHeader(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
      );
}

class _ToiletTile extends StatelessWidget {
  final String name;
  final String? sub;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ToiletTile({
    required this.name,
    this.sub,
    required this.leading,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: leading,
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: (sub != null && sub!.isNotEmpty)
            ? Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              )
            : null,
        trailing: trailing,
      );
}
