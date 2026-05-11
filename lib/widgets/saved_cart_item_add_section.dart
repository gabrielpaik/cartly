import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_runtime_copy.dart';
import 'cartly_symbol_icon.dart';

final _priceFormatter = NumberFormat('#,###');
String _fmt(int v) => _priceFormatter.format(v);

class SavedCartItemAddSection extends StatefulWidget {
  final bool isEditing;
  final void Function(String name, int price) onAdd;
  final String addButtonText;

  const SavedCartItemAddSection({
    super.key,
    required this.isEditing,
    required this.onAdd,
    this.addButtonText = '상품 추가하기',
  });

  @override
  State<SavedCartItemAddSection> createState() =>
      _SavedCartItemAddSectionState();
}

class _SavedCartItemAddSectionState extends State<SavedCartItemAddSection> {
  bool _open = false;

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _open = !_open);

  void _submit() {
    final name = _nameCtrl.text.trim();
    final raw = _priceCtrl.text.replaceAll(',', '').trim();
    final price = int.tryParse(raw) ?? 0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppRuntimeCopy.text([
              'cartDetail',
              'validation',
              'namePriceRequired',
            ], '상품명/가격을 확인해주세요'),
          ),
        ),
      );
      return;
    }

    widget.onAdd(name, price);
    _nameCtrl.clear();
    _priceCtrl.clear();
    setState(() => _open = false);
  }

  @override
  void didUpdateWidget(covariant SavedCartItemAddSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isEditing && !widget.isEditing) {
      _nameCtrl.clear();
      _priceCtrl.clear();
      if (_open) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) return const SizedBox.shrink();

    return Column(
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CartlySymbolIcon.sf(
                  _open ? 'xmark' : 'plus',
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _open
                      ? AppRuntimeCopy.text(['common', 'cancel'], '닫기')
                      : widget.addButtonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppRuntimeCopy.text([
                      'cartDetail',
                      'nameLabel',
                    ], '상품명'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: AppRuntimeCopy.text([
                      'cartDetail',
                      'priceLabel',
                    ], '가격'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final raw = v.replaceAll(',', '');
                    final n = int.tryParse(raw);
                    if (n == null) return;
                    final formatted = _fmt(n);
                    if (formatted != v) {
                      _priceCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _toggle,
                      child: Text(
                        AppRuntimeCopy.text(['common', 'cancel'], '취소'),
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
                      onPressed: _submit,
                      child: Text(
                        AppRuntimeCopy.text(['common', 'confirm'], '추가'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
