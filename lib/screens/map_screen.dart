import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/toilet.dart';
import '../services/toilet_service.dart';
import '../services/location_service.dart';
import '../services/favorites_service.dart';
import '../widgets/toilet_bottom_sheet.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/toilet_list_panel.dart';
import 'onboarding_screen.dart';
import 'community_screen.dart';
import 'community_detail_screen.dart';
import 'my_reviews_screen.dart';
import 'policy_screen.dart';
import '../services/community_service.dart';
import '../services/history_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  int _currentIndex = 0;
  int _favoritesRefreshKey = 0;

  LatLng _center = const LatLng(37.5665, 126.9780);
  double _currentZoom = 15.0;
  double _radiusMeters = 1000;
  String _selectedType = 'all';

  bool _filterDisabled = false;
  bool _filterBabyChanging = false;
  bool _filterFreeOnly = false;

  List<Toilet> _toilets = [];
  List<CommunityToilet> _communityToilets = [];
  Set<String> _favorites = {};
  bool _loading = false;
  bool _locating = false;
  bool _hasNetworkError = false;
  bool _permissionPermanentlyDenied = false;
  LatLng? _userLocation;

  String? _selectedToiletId;
  String? _selectedCommunityId;
  LatLng? _pinnedLocation;

  List<Marker> _toiletMarkers = [];
  List<Marker> _communityMarkers = [];

  StreamSubscription<Position>? _positionSub;

  List<Toilet> get _displayToilets {
    var list = _toilets;
    // '공중' 선택 시 간이·이동 포함
    if (_selectedType == 'public') {
      list = list
          .where((t) =>
              t.type == 'public' || t.type == 'simple' || t.type == 'mobile')
          .toList();
    } else if (_selectedType == 'dev') {
      list = list.where((t) => t.type == 'dev').toList();
    }
    if (_filterDisabled) {
      list = list
          .where((t) => t.disabledMaleToilets > 0 || t.disabledFemaleToilets > 0)
          .toList();
    }
    if (_filterBabyChanging) {
      list = list
          .where((t) => t.babyChangingMale == true || t.babyChangingFemale == true)
          .toList();
    }
    if (_filterFreeOnly) {
      list = list.where((t) => !t.isPaid).toList();
    }
    return list;
  }

  bool get _hasExtraFilter => _filterDisabled || _filterBabyChanging || _filterFreeOnly;
  int get _extraFilterCount =>
      [_filterDisabled, _filterBabyChanging, _filterFreeOnly].where((v) => v).length;

  @override
  void initState() {
    super.initState();
    FavoritesService.getAll().then((favs) {
      if (mounted) setState(() => _favorites = favs);
    });
    // community toilets는 _loadToilets() 내에서 함께 로드됨 (_initLocation → _loadToilets)
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (mounted) setState(() => _locating = true);
    final result = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (result.isOk) {
      final latlng = LatLng(result.lat!, result.lng!);
      setState(() {
        _center = latlng;
        _userLocation = latlng;
        _locating = false;
      });
      try {
        _mapController.move(latlng, _currentZoom);
      } catch (_) {}
      if (result.fromIp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS 불가 — IP 기반 위치 사용 중 (도시 수준 정확도)'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } else {
      setState(() => _locating = false);
      // 영구 권한 거부 여부 확인
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _permissionPermanentlyDenied = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위치를 가져올 수 없습니다. 기본 위치(서울)를 사용합니다.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    await _loadToilets();
    _startPositionStream();
  }

  void _startPositionStream() {
    try {
      _positionSub =
          LocationService.getPositionStream(distanceFilterMeters: 300).listen(
        (pos) {
          if (!mounted) return;
          final newCenter = LatLng(pos.latitude, pos.longitude);
          setState(() {
            _center = newCenter;
            _userLocation = newCenter;
          });
          _mapController.move(newCenter, _currentZoom);
          _loadToilets();
        },
        onError: (_) {},   // geolocator Windows threading error 무시
        cancelOnError: false,
      );
    } catch (_) {}
  }

  Future<void> _loadToilets() async {
    if (_loading) return;
    setState(() { _loading = true; _hasNetworkError = false; });
    try {
      final apiType = (_selectedType == 'all' ||
              _selectedType == 'public' ||
              _selectedType == 'community')
          ? null
          : _selectedType;
      // 공식 화장실 + 커뮤니티 화장실을 동시에 로드, 둘 다 반경 필터 적용
      final results = await Future.wait([
        ToiletService.getNearby(
          lat: _center.latitude,
          lng: _center.longitude,
          radiusMeters: _radiusMeters,
          type: apiType,
        ),
        CommunityService.getToilets(
          lat: _center.latitude,
          lng: _center.longitude,
          radiusMeters: _radiusMeters,
        ),
      ]);
      if (mounted) {
        setState(() {
          _toilets = results[0] as List<Toilet>;
          _communityToilets = results[1] as List<CommunityToilet>;
          _loading = false;
          _rebuildMarkers();
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasNetworkError = true; });
    }
  }

  Future<void> _onFavoriteToggled() async {
    final favs = await FavoritesService.getAll();
    if (mounted) setState(() { _favorites = favs; _rebuildMarkers(); });
  }

  Future<void> _loadCommunityToilets() async {
    final list = await CommunityService.getToilets(
      lat: _center.latitude,
      lng: _center.longitude,
      radiusMeters: _radiusMeters,
    );
    if (mounted) setState(() => _communityToilets = list);
  }

  // ── 마커 캐시 ─────────────────────────────────────────────────────

  void _rebuildMarkers() {
    _toiletMarkers = _buildMarkers();
    _communityMarkers = _communityToilets
        .where((t) => t.latitude != null && t.longitude != null)
        .map(_buildCommunityMarker)
        .toList();
  }

  // ── 마커 ────────────────────────────────────────────────────────

  Marker _buildUserMarker(LatLng point) => Marker(
        point: point,
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 6, spreadRadius: 1),
            ],
          ),
        ),
      );

  Marker _buildPinMarker(LatLng point) => Marker(
        point: point,
        width: 36,
        height: 48,
        alignment: Alignment.bottomCenter,
        child: Icon(
          Icons.location_on,
          size: 48,
          color: Colors.red.shade500,
          shadows: const [
            Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      );

  List<Marker> _buildMarkers() {
    final toilets = _displayToilets;
    if (toilets.isEmpty) return [];

    if (_currentZoom >= 14) {
      return toilets.map(_buildPillMarker).toList();
    }

    final gridSize = _currentZoom < 12 ? 0.05 : 0.02;
    final Map<String, List<Toilet>> groups = {};
    for (final t in toilets) {
      final key =
          '${(t.latitude / gridSize).round()}_${(t.longitude / gridSize).round()}';
      (groups[key] ??= []).add(t);
    }

    final markers = <Marker>[];
    for (final group in groups.values) {
      if (group.length == 1) {
        markers.add(_buildPillMarker(group.first));
      } else {
        final lat =
            group.map((t) => t.latitude).reduce((a, b) => a + b) / group.length;
        final lng =
            group.map((t) => t.longitude).reduce((a, b) => a + b) / group.length;
        markers.add(_buildClusterMarker(LatLng(lat, lng), group.length));
      }
    }
    return markers;
  }

  Color _typeColor(String type) => switch (type) {
        'public' => Colors.blue,
        'open' => Colors.green,
        'simple' => Colors.orange,
        'mobile' => Colors.purple,
        _ => Colors.grey,
      };

  String _typeShortLabel(String type) => switch (type) {
        'public' => '공중',
        'open' => '개방',
        'simple' => '간이',
        'mobile' => '이동',
        _ => '화장실',
      };

  Marker _buildPillMarker(Toilet t) {
    final isSelected = t.id == _selectedToiletId;
    final isFav = _favorites.contains(t.id);
    final color = isFav ? Colors.red.shade400 : _typeColor(t.type);
    final label =
        t.distanceMeters != null ? t.distanceLabel : _typeShortLabel(t.type);

    const double w = 88;
    const double wSel = 104;

    return Marker(
      point: LatLng(t.latitude, t.longitude),
      width: isSelected ? wSel : w,
      height: isSelected ? 58 : 54,
      child: GestureDetector(
        onTap: () => _onMarkerTap(t),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 거리 pill ──────────────────────────────────────
            Container(
              width: isSelected ? wSel : w,
              height: isSelected ? 36 : 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: isSelected ? 0 : 2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2),
                        const BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2)),
                      ]
                    : const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚽', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // ── 화장실 이름 ────────────────────────────────────
            Container(
              width: isSelected ? wSel : w,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                t.name,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildClusterMarker(LatLng point, int count) => Marker(
        point: point,
        width: 58,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
          ),
          child: Center(
            child: Text(
              '$count곳',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );

  String _communityDistanceLabel(CommunityToilet t) {
    if (_userLocation == null || t.latitude == null || t.longitude == null) {
      return t.placeTypeLabel;
    }
    final m = Geolocator.distanceBetween(
      _userLocation!.latitude, _userLocation!.longitude,
      t.latitude!, t.longitude!,
    );
    return m < 1000 ? '${m.round()}m' : '${(m / 1000).toStringAsFixed(1)}km';
  }

  Marker _buildCommunityMarker(CommunityToilet t) {
    final isSelected = t.id == _selectedCommunityId;
    final label = _communityDistanceLabel(t);

    const double w = 96;
    const double wSel = 110;

    return Marker(
      point: LatLng(t.latitude!, t.longitude!),
      width: isSelected ? wSel : w,
      height: isSelected ? 58 : 54,
      child: GestureDetector(
        onTap: () => _onCommunityMarkerTap(t),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 거리 pill ──────────────────────────────────────
            Container(
              width: isSelected ? wSel : w,
              height: isSelected ? 36 : 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple.shade400 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.purple.shade400, width: isSelected ? 0 : 2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: Colors.purple.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2),
                        const BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2)),
                      ]
                    : const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.placeTypeEmoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // ── 화장실 이름 ────────────────────────────────────
            Container(
              width: isSelected ? wSel : w,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                t.name,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onCommunityMarkerTap(CommunityToilet toilet) {
    setState(() {
      _selectedCommunityId = toilet.id;
      _selectedToiletId = null;
      _rebuildMarkers();
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(toilet: toilet),
      ),
    ).then((_) {
      if (mounted) setState(() { _selectedCommunityId = null; _rebuildMarkers(); });
      _loadCommunityToilets();
    });
  }

  void _onMarkerTap(Toilet toilet) {
    setState(() {
      _selectedToiletId = toilet.id;
      _selectedCommunityId = null;
      _rebuildMarkers();
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ToiletBottomSheet(
        toilet: toilet,
        onFavoriteToggled: _onFavoriteToggled,
      ),
    ).then((_) {
      if (mounted) setState(() { _selectedToiletId = null; _rebuildMarkers(); });
    });
  }

  void _showExtraFilterModal() {
    bool tmpDisabled = _filterDisabled;
    bool tmpBaby = _filterBabyChanging;
    bool tmpFree = _filterFreeOnly;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('상세 필터',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setInner(() {
                        tmpDisabled = false;
                        tmpBaby = false;
                        tmpFree = false;
                      }),
                      child: const Text('초기화'),
                    ),
                  ],
                ),
                const Divider(),
                SwitchListTile(
                  dense: true,
                  title: const Text('장애인 화장실 있음'),
                  subtitle: const Text('장애인용 변기가 1개 이상인 곳'),
                  value: tmpDisabled,
                  onChanged: (v) => setInner(() => tmpDisabled = v),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('기저귀 교환대 있음'),
                  value: tmpBaby,
                  onChanged: (v) => setInner(() => tmpBaby = v),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('무료만 보기'),
                  value: tmpFree,
                  onChanged: (v) => setInner(() => tmpFree = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _filterDisabled = tmpDisabled;
                        _filterBabyChanging = tmpBaby;
                        _filterFreeOnly = tmpFree;
                        _rebuildMarkers();
                      });
                    },
                    child: const Text('적용'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRadiusPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [500, 1000, 2000, 5000].map((r) {
          return ListTile(
            title: Text('${(r / 1000).toStringAsFixed(1)}km'),
            selected: _radiusMeters == r,
            onTap: () {
              Navigator.pop(context);
              setState(() => _radiusMeters = r.toDouble());
              _loadToilets();
            },
          );
        }).toList(),
      ),
    );
  }

  // ── 반경 원 그리기 ───────────────────────────────────────────────

  List<LatLng> _generateCirclePoints(LatLng center, double radiusMeters) {
    const degreePerStep = 6;
    final points = <LatLng>[];
    for (int i = 0; i < 360; i += degreePerStep) {
      final angle = (i * math.pi) / 180;
      final latOffset = (radiusMeters / 111320) * math.cos(angle);
      final lngOffset = (radiusMeters / (111320 * math.cos(center.latitude * math.pi / 180))) * math.sin(angle);
      points.add(LatLng(center.latitude + latOffset, center.longitude + lngOffset));
    }
    return points;
  }

  // ── 지도 탭 본문 ─────────────────────────────────────────────────

  Widget _buildMapBody() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _currentZoom,
            onMapEvent: (MapEvent event) {
              if (event is MapEventMoveEnd) {
                setState(() {
                  _center = event.camera.center;
                  _currentZoom = event.camera.zoom;
                  _rebuildMarkers();
                });
                _loadToilets();
              } else if (event is MapEventScrollWheelZoom ||
                  event is MapEventDoubleTapZoom) {
                setState(() => _currentZoom = event.camera.zoom);
              }
            },
            onTap: (_, point) => setState(() => _pinnedLocation = point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.toilet_app',
            ),
            if (_userLocation != null)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _generateCirclePoints(_userLocation!, 1000),
                    color: Colors.red.withValues(alpha: 0.15),
                    borderColor: Colors.red,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(markers: _toiletMarkers),
            MarkerLayer(markers: _communityMarkers),
            if (_userLocation != null)
              MarkerLayer(markers: [_buildUserMarker(_userLocation!)]),
            if (_pinnedLocation != null)
              MarkerLayer(markers: [_buildPinMarker(_pinnedLocation!)]),
          ],
        ),

        // 상단 검색바 + 로딩
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MapSearchBar(
                onSelected: (selection) {
                  _center = selection.latlng;
                  try {
                    _mapController.move(selection.latlng, 16);
                  } catch (_) {}
                  _loadToilets();
                  if (selection.toilet != null) {
                    setState(() => _pinnedLocation = null);
                    _onMarkerTap(selection.toilet!);
                  } else if (selection.communityToilet != null) {
                    setState(() => _pinnedLocation = null);
                    _onCommunityMarkerTap(selection.communityToilet!);
                  } else {
                    setState(() => _pinnedLocation = selection.latlng);
                  }
                },
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),

        // 내 위치 + 줌 버튼 (우측)
        Positioned(
          right: 12,
          bottom: 200,
          child: Column(
            children: [
              _MapIconButton(
                icon: _locating ? null : Icons.my_location,
                loading: _locating,
                tooltip: '내 위치',
                onTap: _locating ? null : _initLocation,
              ),
              const SizedBox(height: 8),
              _MapIconButton(icon: Icons.add, tooltip: '확대', onTap: () {
                final z = (_currentZoom + 1).clamp(3.0, 19.0);
                _mapController.move(_center, z);
                setState(() => _currentZoom = z);
              }),
              const SizedBox(height: 4),
              _MapIconButton(icon: Icons.remove, tooltip: '축소', onTap: () {
                final z = (_currentZoom - 1).clamp(3.0, 19.0);
                _mapController.move(_center, z);
                setState(() => _currentZoom = z);
              }),
            ],
          ),
        ),

        // 네트워크 오류 배너
        if (_hasNetworkError)
          Positioned(
            left: 16,
            right: 16,
            bottom: 220,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('화장실 데이터를 불러오지 못했습니다.',
                          style: TextStyle(fontSize: 13)),
                    ),
                    TextButton(
                      onPressed: _loadToilets,
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 위치 권한 영구 거부 오버레이
        if (_permissionPermanentlyDenied)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off_rounded,
                            size: 56, color: Colors.orange),
                        const SizedBox(height: 14),
                        const Text('위치 권한이 필요합니다',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text(
                          '주변 화장실을 찾으려면 위치 접근 권한이 필요합니다.\n설정에서 권한을 허용해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(
                                    () => _permissionPermanentlyDenied = false),
                                child: const Text('나중에'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  await Geolocator.openAppSettings();
                                  if (mounted) {
                                    setState(() =>
                                        _permissionPermanentlyDenied = false);
                                  }
                                },
                                child: const Text('설정 열기'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 하단 목록 패널
        ToiletListPanel(
          toilets: _displayToilets,
          communityToilets: _communityToilets,
          onToiletTap: _onMarkerTap,
          onCommunityToiletTap: _onCommunityMarkerTap,
          selectedType: _selectedType,
          onTypeChanged: (type) {
            setState(() { _selectedType = type; _rebuildMarkers(); });
            _loadToilets();
          },
          radiusMeters: _radiusMeters,
          onRadiusTap: _showRadiusPicker,
          hasExtraFilter: _hasExtraFilter,
          extraFilterCount: _extraFilterCount,
          onExtraFilterTap: _showExtraFilterModal,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildMapBody(),
          _FavoritesBody(
            key: ValueKey(_favoritesRefreshKey),
            favorites: _favorites,
            onFavoriteToggled: _onFavoriteToggled,
          ),
          const CommunityScreen(),
          const _SettingsBody(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() {
          if (i == 1) _favoritesRefreshKey++; // 즐겨찾기 탭 진입 시 히스토리 갱신
          _currentIndex = i;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: '즐겨찾기',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '커뮤니티',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

// ── 지도 위 아이콘 버튼 ──────────────────────────────────────────────

class _MapIconButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool loading;

  const _MapIconButton({
    this.icon,
    this.onTap,
    this.tooltip,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, size: 20, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 즐겨찾기 탭 ──────────────────────────────────────────────────────

class _FavoritesBody extends StatefulWidget {
  final Set<String> favorites;
  final VoidCallback onFavoriteToggled;

  const _FavoritesBody({
    super.key,
    required this.favorites,
    required this.onFavoriteToggled,
  });

  @override
  State<_FavoritesBody> createState() => _FavoritesBodyState();
}

class _FavoritesBodyState extends State<_FavoritesBody> {
  List<Toilet> _favToilets = [];
  List<Toilet> _historyToilets = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_FavoritesBody old) {
    super.didUpdateWidget(old);
    if (old.favorites != widget.favorites) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final historyIds = await HistoryService.getAll();
    final results = await Future.wait([
      widget.favorites.isEmpty
          ? Future.value(<Toilet>[])
          : ToiletService.getByIds(widget.favorites.toList()),
      historyIds.isEmpty
          ? Future.value(<Toilet>[])
          : ToiletService.getByIds(historyIds),
    ]);
    if (!mounted) return;

    // 최근 본 화장실: historyIds 순서(최신순) 유지
    final histMap = {for (final t in results[1]) t.id: t};
    final ordered =
        historyIds.map((id) => histMap[id]).whereType<Toilet>().toList();

    setState(() {
      _favToilets = results[0];
      _historyToilets = ordered;
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    await HistoryService.clear();
    if (mounted) setState(() => _historyToilets = []);
  }

  void _openToilet(Toilet t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ToiletBottomSheet(
        toilet: t,
        onFavoriteToggled: widget.onFavoriteToggled,
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // 탭 제목
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: const Text(
                '즐겨찾기',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // ── 즐겨찾기 추가한 화장실 ──
          _SectionHeader(title: '즐겨찾기 추가한 화장실', count: _favToilets.length),
          if (_favToilets.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyHint(
                icon: Icons.favorite_border,
                message: '즐겨찾기한 화장실이 없습니다.',
                sub: '지도에서 화장실을 탭해 ♡ 버튼으로 추가하세요.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FavTile(
                  toilet: _favToilets[i],
                  isFav: true,
                  onTap: () => _openToilet(_favToilets[i]),
                ),
                childCount: _favToilets.length,
              ),
            ),

          // ── 최근 본 화장실 ──
          _SectionHeader(
            title: '최근 본 화장실',
            count: _historyToilets.length,
            trailing: _historyToilets.isNotEmpty
                ? TextButton(
                    onPressed: _clearHistory,
                    child: const Text('전체 삭제',
                        style: TextStyle(color: Colors.red, fontSize: 13)),
                  )
                : null,
          ),
          if (_historyToilets.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyHint(
                icon: Icons.history,
                message: '최근 본 화장실이 없습니다.',
                sub: '지도에서 화장실을 탭하면 여기에 기록됩니다.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FavTile(
                  toilet: _historyToilets[i],
                  isFav: false,
                  onTap: () => _openToilet(_historyToilets[i]),
                ),
                childCount: _historyToilets.length,
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

// ── 섹션 헤더 ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ── 빈 상태 힌트 ─────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? sub;

  const _EmptyHint({
    required this.icon,
    required this.message,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey.shade500)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// ── 화장실 목록 아이템 ───────────────────────────────────────────────

class _FavTile extends StatelessWidget {
  final Toilet toilet;
  final bool isFav;
  final VoidCallback onTap;

  const _FavTile({
    required this.toilet,
    required this.isFav,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = toilet;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isFav ? Colors.red : Colors.blue)
                  .withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isFav ? '❤️' : '🚽',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          title: Text(
            t.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            t.roadAddress ?? t.address ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: t.avgCleanliness != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    Text(
                      t.avgCleanliness!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                )
              : null,
        ),
        const Divider(height: 1, indent: 56),
      ],
    );
  }
}

// ── 설정 탭 ──────────────────────────────────────────────────────────

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  Future<void> _launchAppReview(BuildContext context) async {
    const packageName = 'com.example.toilet_app';
    final storeUri = Uri.parse('market://details?id=$packageName');
    final webUri =
        Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

    if (!await launchUrl(storeUri, mode: LaunchMode.externalApplication)) {
      if (!await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('앱 리뷰 남기기'),
              content: const Text(
                '구글 플레이스토어 또는 앱스토어에서\n'
                '"화장실 찾기" 앱을 검색해\n'
                '리뷰를 남겨주세요.\n\n'
                '소중한 의견이 앱 개선에 도움이 됩니다. 😊',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.grey.shade100,
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Text('설정',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),

            // ── 서비스 안내 ──
            _SettingSection(label: '서비스 안내', children: [
              _SettingTile(
                icon: Icons.rate_review_outlined,
                title: '내가 쓴 평가/후기',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const MyReviewsScreen()),
                ),
              ),
              _SettingTile(
                icon: Icons.star_outline,
                title: '앱 리뷰 남기기',
                onTap: () => _launchAppReview(context),
              ),
            ]),

            // ── 약관 및 정책 ──
            _SettingSection(label: '약관 및 정책', children: [
              _SettingTile(
                icon: Icons.description_outlined,
                title: '이용약관',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PolicyScreen.terms()),
                ),
              ),
              _SettingTile(
                icon: Icons.privacy_tip_outlined,
                title: '개인정보 처리방침',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PolicyScreen.privacy()),
                ),
              ),
              _SettingTile(
                icon: Icons.code,
                title: '오픈소스 라이선스',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '화장실 찾기',
                  applicationVersion: 'v1.0.0',
                ),
              ),
            ]),

            // ── 앱 정보 ──
            _SettingSection(label: '앱 정보', children: [
              _SettingTile(
                icon: Icons.help_outline,
                title: '앱 설명',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const OnboardingScreen(fromSettings: true)),
                ),
              ),
              _SettingTile(
                icon: Icons.info_outline,
                title: '버전 정보',
                value: 'v1.0.0',
              ),
              _SettingTile(
                icon: Icons.storage_outlined,
                title: '데이터 출처',
                value: '행정안전부 공공데이터포털',
              ),
              _SettingTile(
                icon: Icons.map_outlined,
                title: '지도 제공',
                value: 'OpenStreetMap',
              ),
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 컨테이너 ────────────────────────────────────────────────────

class _SettingSection extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _SettingSection({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.3),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── 설정 항목 ────────────────────────────────────────────────────────

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 22, color: Colors.grey.shade700),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
          : value != null
              ? Text(value!,
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13))
              : null,
    );
  }
}
