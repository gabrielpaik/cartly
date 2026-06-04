import 'package:flutter/material.dart';

import '../models/recognized_item.dart';
import '../services/app_runtime_copy.dart';
import 'scan_ui_helpers.dart';

class RecognizedResultCard extends StatefulWidget {
  final RecognizedItem item;
  final void Function(RecognizedItem updated) onChanged;
  final Future<void> Function(RecognizedItem item) onAdd;
  final String? title;

  final bool startEditing;
  final bool showCancel;
  final VoidCallback? onCancel;
  final String? cancelButtonText;
  final String addButtonText;

  const RecognizedResultCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onAdd,
    this.startEditing = false,
    this.showCancel = false,
    this.onCancel,
    this.cancelButtonText,
    this.addButtonText = '카트에 추가',
    this.title,
  });

  @override
  State<RecognizedResultCard> createState() => _RecognizedResultCardState();
}

class _RecognizedResultCardState extends State<RecognizedResultCard> {
  late bool isEditing;
  late final TextEditingController nameCtrl;
  late final TextEditingController priceCtrl;

  @override
  void initState() {
    super.initState();
    isEditing = widget.startEditing;
    nameCtrl = TextEditingController(text: widget.item.name);
    priceCtrl = TextEditingController(
      text: widget.item.price > 0 ? fmtScanPrice(widget.item.price) : '',
    );
  }

  @override
  void didUpdateWidget(covariant RecognizedResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.startEditing != widget.startEditing) {
      if (widget.startEditing && !isEditing) isEditing = true;
    }

    if (oldWidget.item.name != widget.item.name) {
      nameCtrl.text = widget.item.name;
    }
    if (oldWidget.item.price != widget.item.price) {
      priceCtrl.text = widget.item.price > 0 ? fmtScanPrice(widget.item.price) : '';
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  void startEdit() => setState(() => isEditing = true);

  void cancelEdit() {
    nameCtrl.text = widget.item.name;
    priceCtrl.text = widget.item.price > 0 ? fmtScanPrice(widget.item.price) : '';
    setState(() => isEditing = false);
  }

  RecognizedItem? applyEdits() {
    final name = nameCtrl.text.trim();
    final rawPrice = priceCtrl.text.replaceAll(',', '').trim();
    final parsed = int.tryParse(rawPrice);

    if (name.isEmpty || parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scanNestedText(
              'validation',
              'namePriceRequired',
              '상품명/가격을 확인해주세요',
            ),
          ),
        ),
      );
      return null;
    }

    final updated = widget.item.copyWith(name: name, price: parsed);
    widget.onChanged(updated);
    setState(() => isEditing = false);
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title ?? scanText('recognizedTitle', '인식 결과'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (item.confidence != null)
                _ConfidenceBadge(confidence: item.confidence!),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            scanReviewMessage(item.confidence),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  AppRuntimeCopy.text(['cartDetail', 'nameLabel'], '상품명'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: AppRuntimeCopy.text([
                            'cartDetail',
                            'nameLabel',
                          ], '상품명'),
                        ),
                      )
                    : Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  AppRuntimeCopy.text(['cartDetail', 'priceLabel'], '가격'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: scanText('priceHint', '가격(숫자)'),
                        ),
                        onChanged: (value) {
                          final raw = value.replaceAll(',', '');
                          final number = int.tryParse(raw);
                          if (number == null) return;
                          final formatted = fmtScanPrice(number);
                          if (formatted != value) {
                            priceCtrl.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }
                        },
                      )
                    : Text(
                        '₩${fmtScanPrice(item.price)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.showCancel)
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    widget.cancelButtonText ??
                        AppRuntimeCopy.text(['common', 'cancel'], '취소'),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: isEditing ? cancelEdit : startEdit,
                  child: Text(
                    isEditing
                        ? AppRuntimeCopy.text(['common', 'cancel'], '취소')
                        : AppRuntimeCopy.text(['common', 'edit'], '수정'),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE31837),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  RecognizedItem toAdd = widget.item;

                  if (isEditing) {
                    final updated = applyEdits();
                    if (updated == null) return;
                    toAdd = updated;
                  }

                  await widget.onAdd(toAdd);
                },
                child: Text(
                  widget.addButtonText,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final label = scanConfidenceLabel(confidence);
    final color = confidence >= 0.85
        ? const Color(0xFF1E8E3E)
        : confidence >= 0.65
        ? const Color(0xFFB26A00)
        : const Color(0xFFE31837);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${(confidence * 100).round()}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
