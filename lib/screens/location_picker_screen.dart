import 'dart:async';
import 'dart:convert';
import 'dart:math' show atan2, cos, pi, sin;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/search_service.dart';

class LocationPickResult {
  final LatLng latlng;
  final String address;
  const LocationPickResult({required this.latlng, required this.address});
}

/// 지도 중앙 핀 방식으로 위치를 선택하는 풀스크린 화면.
/// 반환값: [LocationPickResult] or null (취소)
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialCenter;
  const LocationPickerScreen({super.key, this.initialCenter});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  LatLng _center = const LatLng(37.5665, 126.9780);
  LatLng? _userLocation;
  String _address = '지도를 이동해 위치를 선택하세요';
  bool _geocoding = false;
  bool _locating = false;
  bool _mapMoving = false;

  List<SearchResult> _searchResults = [];
  bool _searching = false;

  Timer? _debounce;
  Timer? _searchDebounce;

  static Map<String, String> get _headers =>
      kIsWeb ? {} : {'User-Agent': 'toilet_app/1.0'};

  @override
  void initState() {
    super.initState();
    if (widget.initialCenter != null) {
      _center = widget.initialCenter!;
      _reverseGeocode(_center);
    } else {
      _initLocation();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _mapController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    final result = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (result.isOk) {
      final latlng = LatLng(result.lat!, result.lng!);
      setState(() {
        _center = latlng;
        _userLocation = latlng;
        _locating = false;
      });
      try { _mapController.move(latlng, 16); } catch (_) {}
      _reverseGeocode(latlng);
    } else {
      setState(() => _locating = false);
      _reverseGeocode(_center);
    }
  }

  Future<void> _reverseGeocode(LatLng latlng) async {
    setState(() { _geocoding = true; _address = '주소 조회 중...'; });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${latlng.latitude}',
        'lon': '${latlng.longitude}',
        'format': 'json',
        'accept-language': 'ko',
      });
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final display = data['display_name'] as String? ?? '';
        // 한국 주소는 뒤에서 국가명 제거
        final cleaned = display.replaceAll(', 대한민국', '').trim();
        setState(() { _address = cleaned.isEmpty ? '주소 없음' : cleaned; });
      } else {
        setState(() => _address = '주소를 가져올 수 없습니다');
      }
    } catch (_) {
      if (mounted) setState(() => _address = '주소를 가져올 수 없습니다');
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveStart) {
      _debounce?.cancel();
      setState(() => _mapMoving = true);
    } else if (event is MapEventMoveEnd) {
      setState(() {
        _center = event.camera.center;
        _mapMoving = false;
      });
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        _reverseGeocode(_center);
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await SearchService.search(query);
      if (mounted) setState(() { _searchResults = results; _searching = false; });
    });
  }

  Future<void> _doSearch(String query) async {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await SearchService.search(query);
    if (mounted) setState(() { _searchResults = results; _searching = false; });
  }

  void _selectSearchResult(SearchResult r) {
    _searchDebounce?.cancel();
    _searchFocus.unfocus();
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _searching = false;
      _center = r.latlng;
    });
    _debounce?.cancel();
    try { _mapController.move(r.latlng, 16); } catch (_) {}
    _reverseGeocode(r.latlng);
  }

  void _confirm() {
    if (_geocoding || _mapMoving) return;
    Navigator.of(context).pop(
      LocationPickResult(latlng: _center, address: _address),
    );
  }

  // ── 화살표 헬퍼 ───────────────────────────────────────────────────

  static LatLng _midpoint(LatLng a, LatLng b) =>
      LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);

  /// 두 좌표 간 방위각 (라디안, 북쪽=0, 시계방향 양수)
  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;
    final y = sin(dLng) * cos(lat2);
    final x =
        cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return atan2(y, x);
  }

  bool get _showArrow {
    if (_userLocation == null) return false;
    final dlat = (_center.latitude - _userLocation!.latitude).abs();
    final dlng = (_center.longitude - _userLocation!.longitude).abs();
    return dlat > 0.00003 || dlng > 0.00003; // ~3m 이상 떨어진 경우만 표시
  }

  @override
  Widget build(BuildContext context) {
    final showDropdown = _searchResults.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 선택', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // ── 지도 ─────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              onMapEvent: _onMapEvent,
              onTap: (tapPosition, point) {
                // 검색 필드에 포커스가 있으면 지도 탭을 무시
                if (_searchFocus.hasFocus) return;
                // 검색 결과 드롭다운이 열려 있으면 닫기만 하고 이동하지 않음
                if (_searchResults.isNotEmpty) {
                  setState(() { _searchResults = []; _searching = false; });
                  return;
                }
                _debounce?.cancel();
                setState(() {
                  _center = point;
                  _mapMoving = false;
                });
                try {
                  _mapController.move(
                      point, _mapController.camera.zoom);
                } catch (_) {}
                _debounce =
                    Timer(const Duration(milliseconds: 300), () {
                  _reverseGeocode(point);
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.toilet_app',
              ),
              // 점선 (내 위치 → 선택 핀)
              if (_showArrow)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_userLocation!, _center],
                      color: Colors.blue.shade400,
                      strokeWidth: 2.5,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
              // 중간 지점 화살표
              if (_showArrow)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _midpoint(_userLocation!, _center),
                      width: 28,
                      height: 28,
                      child: Transform.rotate(
                        angle: _bearing(_userLocation!, _center),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.blue.shade500,
                          size: 22,
                          shadows: const [
                            Shadow(
                                color: Colors.white,
                                blurRadius: 4,
                                offset: Offset(0, 0)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              // 내 위치 마커 (파란 점)
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black38,
                                blurRadius: 5,
                                spreadRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── 중앙 핀 ────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _mapMoving ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: const Text('📍', style: TextStyle(fontSize: 36)),
                ),
                // 핀 그림자 점
                Container(
                  width: 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

          // ── 상단: 검색 바 ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      decoration: InputDecoration(
                        hintText: '장소 검색 (예: 강남역, 스타벅스)',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              )
                            : _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _searchDebounce?.cancel();
                                      setState(() { _searchResults = []; _searching = false; });
                                    },
                                  )
                                : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _doSearch,
                    ),
                  ),
                  if (showDropdown)
                    Card(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      elevation: 4,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, i) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = _searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined,
                                size: 20),
                            title: Text(r.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                            onTap: () => _selectSearchResult(r),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── 내 위치 버튼 ────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 130,
            child: FloatingActionButton.small(
              heroTag: 'location',
              tooltip: '내 위치',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              onPressed: _locating ? null : _initLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          // ── 하단 주소 표시 + 확인 버튼 ─────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 14, 16, 16 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, -2)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      const Text('선택된 위치',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_geocoding || _mapMoving)
                    Row(children: [
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5)),
                      const SizedBox(width: 8),
                      Text('주소 조회 중...',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500])),
                    ])
                  else
                    Text(
                      _address,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed:
                          (_geocoding || _mapMoving) ? null : _confirm,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('이 위치로 선택',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
