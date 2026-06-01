import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/community_service.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';

class CommunityDetailScreen extends StatefulWidget {
  final CommunityToilet toilet;
  const CommunityDetailScreen({super.key, required this.toilet});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  List<CommunityReview> _reviews = [];
  bool _loading = false;
  late CommunityToilet _toilet;

  @override
  void initState() {
    super.initState();
    _toilet = widget.toilet;
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _loading = true);
    final list = await CommunityService.getReviews(_toilet.id);
    if (mounted) setState(() { _reviews = list; _loading = false; });
  }

  List<CommunityReview> get _passwords =>
      _reviews.where((r) => r.password != null && r.password!.isNotEmpty).toList();

  // ── 평가하기 ────────────────────────────────────────────────────

  void _showRatingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunityRatingSheet(
        toiletName: _toilet.name,
        onSubmit: (rating) async {
          await CommunityService.addRating(
            toiletId: _toilet.id,
            rating: rating,
          );
          _loadReviews();
        },
      ),
    );
  }

  // ── 비밀번호 공유 ────────────────────────────────────────────────

  void _showPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PasswordShareSheet(
        onSubmit: (pw) async {
          await CommunityService.addPassword(
            toiletId: _toilet.id,
            password: pw,
          );
          _loadReviews();
        },
      ),
    );
  }

  // ── 길 안내 ─────────────────────────────────────────────────────

  Future<(double?, double?)> _getOrigin() async {
    try {
      final loc = await LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 3));
      if (loc.isOk) return (loc.lat, loc.lng);
    } catch (_) {}
    return (null, null);
  }

  Future<void> _openNavigation() async {
    final t = _toilet;
    if (t.latitude == null || t.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 정보가 없어 길 안내를 사용할 수 없습니다')),
      );
      return;
    }
    if (!mounted) return;
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
              onTap: () async {
                Navigator.pop(context);
                final (lat, lng) = await _getOrigin();
                NavigationService.openGoogleMaps(t.latitude!, t.longitude!,
                    originLat: lat, originLng: lng, name: t.name);
              },
            ),
            ListTile(
              leading: const Text('🟡', style: TextStyle(fontSize: 22)),
              title: const Text('카카오맵'),
              onTap: () async {
                Navigator.pop(context);
                final (lat, lng) = await _getOrigin();
                NavigationService.openKakaoMap(t.latitude!, t.longitude!, t.name,
                    originLat: lat, originLng: lng);
              },
            ),
            ListTile(
              leading: const Text('🟢', style: TextStyle(fontSize: 22)),
              title: const Text('네이버 지도'),
              onTap: () async {
                Navigator.pop(context);
                final (lat, lng) = await _getOrigin();
                NavigationService.openNaverMap(
                    t.latitude!, t.longitude!, t.name, 'com.bsangshop.toilet_app',
                    originLat: lat, originLng: lng);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _toilet;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(t.placeTypeLabel),
              avatar: Text(t.placeTypeEmoji),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 정보 카드 ───────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.address != null && t.address!.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(t.address!,
                                  style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    if (t.description != null && t.description!.isNotEmpty) ...[
                      if (t.address != null) const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(t.description!,
                                  style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    // 평점 표시
                    if (t.ratingCount > 0) ...[
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < (t.avgRating ?? 0).round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 18,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.avgRating!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            ' (${t.ratingCount}명)',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ] else
                      Text(
                        '아직 평가가 없습니다',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${t.createdAt.year}.${t.createdAt.month.toString().padLeft(2, '0')}.${t.createdAt.day.toString().padLeft(2, '0')} 등록',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── 액션 버튼 ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showRatingSheet,
                    icon: const Icon(Icons.star_border, size: 18),
                    label: const Text('평가하기'),
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

            // ── 비밀번호 공유 섹션 ─────────────────────────────
            Row(
              children: [
                Icon(Icons.lock_outlined,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                const Text(
                  '비밀번호 공유',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showPasswordSheet,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('공유하기',
                      style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const Divider(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_passwords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '공유된 비밀번호가 없습니다. 방문 후 공유해 주세요!',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              )
            else
              ..._passwords.map((r) => _PasswordTile(
                    review: r,
                    onCopy: () {
                      Clipboard.setData(
                          ClipboardData(text: r.password!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('클립보드에 복사됐습니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }
}

// ── 비밀번호 타일 ─────────────────────────────────────────────────

class _PasswordTile extends StatefulWidget {
  final CommunityReview review;
  final VoidCallback onCopy;
  const _PasswordTile({required this.review, required this.onCopy});

  @override
  State<_PasswordTile> createState() => _PasswordTileState();
}

class _PasswordTileState extends State<_PasswordTile> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _visible = !_visible),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.amber.shade300, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      _visible
                          ? Icons.lock_open_outlined
                          : Icons.lock_outlined,
                      size: 14,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(width: 8),
                    _visible
                        ? Text(
                            widget.review.password!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                              letterSpacing: 2,
                            ),
                          )
                        : Text(
                            '탭하여 보기',
                            style: TextStyle(
                                fontSize: 13, color: Colors.amber[700]),
                          ),
                  ],
                ),
              ),
            ),
          ),
          if (_visible) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: widget.onCopy,
              tooltip: '복사',
              visualDensity: VisualDensity.compact,
            ),
          ],
          const SizedBox(width: 4),
          Text(
            widget.review.dateLabel,
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ── 평가 바텀 시트 ─────────────────────────────────────────────────

class _CommunityRatingSheet extends StatefulWidget {
  final String toiletName;
  final Future<void> Function(int rating) onSubmit;
  const _CommunityRatingSheet(
      {required this.toiletName, required this.onSubmit});

  @override
  State<_CommunityRatingSheet> createState() =>
      _CommunityRatingSheetState();
}

class _CommunityRatingSheetState extends State<_CommunityRatingSheet> {
  int _stars = 0;
  bool _submitting = false;
  bool _done = false;

  Future<void> _submit() async {
    if (_stars == 0) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_stars);
      if (mounted) setState(() { _submitting = false; _done = true; });
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('평가 제출에 실패했습니다')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: _done
          ? const SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 44),
                    SizedBox(height: 8),
                    Text('평가가 제출됐습니다!',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('화장실 평가하기',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                Text(widget.toiletName,
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 20),
                const Text('청결도',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setState(() => _stars = i + 1),
                      child: Icon(
                        i < _stars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 38,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed:
                        (_stars == 0 || _submitting) ? null : _submit,
                    style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: _submitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('평가 제출',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── 비밀번호 공유 바텀 시트 ───────────────────────────────────────

class _PasswordShareSheet extends StatefulWidget {
  final Future<void> Function(String password) onSubmit;
  const _PasswordShareSheet({required this.onSubmit});

  @override
  State<_PasswordShareSheet> createState() => _PasswordShareSheetState();
}

class _PasswordShareSheetState extends State<_PasswordShareSheet> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_ctrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공유에 실패했습니다')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('비밀번호 공유',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('화장실 잠금 코드를 다른 방문자와 공유하세요',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: '비밀번호 / 잠금 코드',
              hintText: '예) 1234, #0000',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            maxLength: 20,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('공유하기',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
