import 'package:flutter/material.dart';
import '../models/toilet.dart';
import '../services/rating_service.dart';

class RatingSheet extends StatefulWidget {
  final Toilet toilet;
  const RatingSheet({super.key, required this.toilet});

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  int _stars = 0;
  bool? _hasBidet;
  bool? _hasPaper;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) return;
    setState(() => _submitting = true);
    try {
      await RatingService.submit(
        toiletId: widget.toilet.id,
        cleanliness: _stars,
        hasBidet: _hasBidet,
        hasPaper: _hasPaper,
        comment: _commentController.text,
      );
      if (mounted) setState(() { _submitting = false; _done = true; });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('평가 제출에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
      child: _done
            ? const _SuccessView()
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('화장실 평가하기',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(widget.toilet.name,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 20),
                  const Text('청결도',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () => setState(() => _stars = i + 1),
                        child: Icon(
                          i < _stars ? Icons.star : Icons.star_border,
                          color: Colors.amber, size: 36,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ToggleChip(
                        label: '비데 있음',
                        value: _hasBidet,
                        onChanged: (v) => setState(() => _hasBidet = v),
                      ),
                      const SizedBox(width: 8),
                      _ToggleChip(
                        label: '화장지 있음',
                        value: _hasPaper,
                        onChanged: (v) => setState(() => _hasPaper = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: '한줄 평가 (선택)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _stars == 0 || _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('평가 제출'),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;
  const _ToggleChip({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = value == null
        ? Colors.grey
        : value!
            ? Colors.blue
            : Colors.red;
    return GestureDetector(
      onTap: () {
        if (value == null) { onChanged(true); }
        else if (value == true) { onChanged(false); }
        else { onChanged(null); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: value == null ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: value == null ? Colors.grey[300]! : color),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 8),
              Text('평가가 제출됐습니다!',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}
