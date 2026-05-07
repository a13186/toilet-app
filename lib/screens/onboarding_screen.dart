import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_screen.dart';

class OnboardingScreen extends StatefulWidget {
  /// true 이면 설정에서 열린 것 — 완료 시 pop(), onboarding_done 미저장
  final bool fromSettings;
  const OnboardingScreen({super.key, this.fromSettings = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _requestingPermission = false;

  static const _pages = [
    _PageData(
      emoji: '🚽',
      color: Color(0xFF2196F3),
      title: '내 주변 화장실\n한눈에 찾기',
      description: '외출 중 급하게 화장실이 필요할 때\n가장 가까운 화장실을 빠르게 안내합니다',
    ),
    _PageData(
      emoji: '🗺️',
      color: Color(0xFF26A69A),
      title: '지도에서 바로 확인',
      description: '공중·개방·간이 화장실을 지도 위에 표시하고\n유형·거리·시설별 필터로 원하는 곳을 찾으세요',
    ),
    _PageData(
      emoji: '⭐',
      color: Color(0xFFFF7043),
      title: '즐겨찾기 & 리뷰',
      description: '자주 이용하는 화장실을 저장하고\n청결도를 평가해 다른 사람들과 공유하세요',
    ),
    _PageData(
      emoji: '📍',
      color: Color(0xFF5C6BC0),
      title: '위치 권한 허용',
      description: '현재 위치 기반으로 주변 화장실을 찾으려면\n위치 접근 권한이 필요해요',
      isPermissionPage: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (!mounted) return;
    if (widget.fromSettings) {
      // 설정에서 열린 경우 — 이전 화면으로 돌아감
      Navigator.of(context).pop();
      return;
    }
    // 첫 실행 — 완료 플래그 저장 후 지도로 이동
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context2, anim1, anim2) => const MapScreen(),
        transitionsBuilder: (context2, anim, anim2, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _requestPermissionAndComplete() async {
    setState(() => _requestingPermission = true);
    try {
      await Geolocator.requestPermission();
    } catch (_) {}
    if (mounted) setState(() => _requestingPermission = false);
    await _completeOnboarding();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final pageColor = _pages[_currentPage].color;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단: 건너뛰기 ──────────────────────────────────
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: isLast
                    ? const SizedBox()
                    : TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          '건너뛰기',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
              ),
            ),

            // ── 페이지 뷰 ────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardingPageView(page: _pages[i]),
              ),
            ),

            // ── 점 인디케이터 ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? pageColor : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // ── 하단 버튼 ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: isLast
                  ? Column(
                      children: [
                        _PrimaryButton(
                          label: '위치 권한 허용하기',
                          color: pageColor,
                          loading: _requestingPermission,
                          onPressed: _requestPermissionAndComplete,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            '나중에 허용',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      ],
                    )
                  : _PrimaryButton(
                      label: '다음',
                      color: pageColor,
                      onPressed: _nextPage,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 개별 페이지 ──────────────────────────────────────────────────────

class _OnboardingPageView extends StatelessWidget {
  final _PageData page;
  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 아이콘 원형
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(page.emoji, style: const TextStyle(fontSize: 68)),
            ),
          ),
          const SizedBox(height: 44),
          // 제목
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          // 설명
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 버튼 ────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryButton({
    required this.label,
    required this.color,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ── 페이지 데이터 모델 ───────────────────────────────────────────────

class _PageData {
  final String emoji;
  final Color color;
  final String title;
  final String description;
  final bool isPermissionPage;

  const _PageData({
    required this.emoji,
    required this.color,
    required this.title,
    required this.description,
    this.isPermissionPage = false,
  });
}
