import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/community_service.dart';
import 'location_picker_screen.dart';

class AddCommunityToiletScreen extends StatefulWidget {
  const AddCommunityToiletScreen({super.key});

  @override
  State<AddCommunityToiletScreen> createState() =>
      _AddCommunityToiletScreenState();
}

class _AddCommunityToiletScreenState extends State<AddCommunityToiletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _placeType = 'etc';
  bool _submitting = false;
  bool _locationError = false;

  LatLng? _pickedLatLng;
  String? _pickedAddress;

  static const _placeTypes = [
    ('cafe', '☕ 카페'),
    ('restaurant', '🍽️ 음식점'),
    ('convenience', '🏪 편의점'),
    ('building', '🏢 빌딩·사무실'),
    ('etc', '🚪 기타'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialCenter: _pickedLatLng,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _pickedLatLng = result.latlng;
        _pickedAddress = result.address;
        _locationError = false;
      });
    }
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    final hasLocation = _pickedLatLng != null;

    if (!hasLocation) {
      setState(() => _locationError = true);
    }
    if (!formValid || !hasLocation) return;

    setState(() => _submitting = true);
    try {
      await CommunityService.addToilet(
        name: _nameCtrl.text.trim(),
        address: _pickedAddress,
        placeType: _placeType,
        description: _descCtrl.text.trim(),
        latitude: _pickedLatLng!.latitude,
        longitude: _pickedLatLng!.longitude,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('등록 실패'),
            content: SelectableText(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('화장실 등록',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 이름 ─────────────────────────────────────────────
            _SectionLabel(label: '화장실 이름', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: '예) 스타벅스 강남점 1층 화장실',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '이름을 입력해주세요' : null,
            ),
            const SizedBox(height: 16),

            // ── 장소 유형 ─────────────────────────────────────────
            _SectionLabel(label: '장소 유형', required: true),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _placeTypes.map((e) {
                final selected = _placeType == e.$1;
                return ChoiceChip(
                  label: Text(e.$2),
                  selected: selected,
                  onSelected: (_) => setState(() => _placeType = e.$1),
                  labelStyle: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── 위치 (지도 선택 필수) ──────────────────────────────
            _SectionLabel(label: '위치', required: true),
            const SizedBox(height: 8),
            _buildMapAddressInput(),
            const SizedBox(height: 16),

            // ── 추가 정보 ─────────────────────────────────────────
            _SectionLabel(label: '추가 정보'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                hintText: '예) 2층 계단 올라가면 좌측, 코드 필요, 손님만 이용 가능 등',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 28),

            // ── 등록 버튼 ─────────────────────────────────────────
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('등록하기',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Text(
              '등록된 정보는 모든 사용자에게 공개됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  // ── 지도 선택 ────────────────────────────────────────────────────

  Widget _buildMapAddressInput() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_pickedLatLng == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _openMapPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _locationError
                      ? colorScheme.error
                      : colorScheme.outline.withValues(alpha: 0.4),
                  width: _locationError ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _locationError
                    ? colorScheme.errorContainer.withValues(alpha: 0.15)
                    : null,
              ),
              child: Column(
                children: [
                  Icon(Icons.add_location_alt_outlined,
                      size: 40,
                      color: _locationError
                          ? colorScheme.error
                          : Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    '지도에서 위치 선택',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _locationError
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '탭해서 지도에서 정확한 위치를 지정하세요',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          if (_locationError) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                '위치를 선택해주세요',
                style: TextStyle(fontSize: 12, color: colorScheme.error),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pickedAddress ?? '주소 없음',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'lat: ${_pickedLatLng!.latitude.toStringAsFixed(5)}, '
                      'lng: ${_pickedLatLng!.longitude.toStringAsFixed(5)}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _openMapPicker,
          icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
          label: const Text('위치 다시 선택', style: TextStyle(fontSize: 13)),
          style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero),
        ),
      ],
    );
  }
}

// ── 섹션 레이블 ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _SectionLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text('*',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}
