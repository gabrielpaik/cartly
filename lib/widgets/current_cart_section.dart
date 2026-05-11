import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import '../app_support.dart';
import '../services/app_runtime_copy.dart';
import 'cartly_empty_state.dart';
import 'cartly_symbol_icon.dart';

class CurrentCartSection extends StatelessWidget {
  final List<CartItem> items;
  final void Function(CartItem item) onRemove;
  final void Function(CartItem item) onChanged;

  const CurrentCartSection({
    super.key,
    required this.items,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.28,
        child: Center(
          child: CartlyEmptyState(
            icon: const CartlySymbolIcon.sf(
              'basket',
              size: 48,
              color: CartlyColors.textTertiary,
            ),
            iconSize: 48,
            title: AppRuntimeCopy.text([
              'home',
              'currentCartEmpty',
            ], '아직 담은 상품이 없어요'),
          ),
        ),
      );
    }

    return Column(
      children: items
          .map(
            (item) => Dismissible(
              key: ObjectKey(item),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: CartlyColors.semanticDanger,
                  borderRadius: BorderRadius.circular(CartlyRadii.card),
                ),
                child: const CartlySymbolIcon.sf(
                  'trash.fill',
                  color: CartlyColors.onBrandPrimary,
                  size: CartlyIconSizes.row,
                ),
              ),
              onDismissed: (_) => onRemove(item),
              child: CurrentCartItemCard(
                item: item,
                onChanged: () => onChanged(item),
              ),
            ),
          )
          .toList(),
    );
  }
}

class CurrentCartItemCard extends StatefulWidget {
  final CartItem item;
  final VoidCallback onChanged;

  const CurrentCartItemCard({
    super.key,
    required this.item,
    required this.onChanged,
  });

  @override
  State<CurrentCartItemCard> createState() => _CurrentCartItemCardState();
}

class _CurrentCartItemCardState extends State<CurrentCartItemCard> {
  late final TextEditingController _nameController;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
  }

  @override
  void didUpdateWidget(covariant CurrentCartItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.name != widget.item.name &&
        _nameController.text != widget.item.name) {
      _nameController.text = widget.item.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void increase() {
    setState(() => widget.item.quantity++);
    widget.onChanged();
  }

  void decrease() {
    if (widget.item.quantity > 1) {
      setState(() => widget.item.quantity--);
      widget.onChanged();
    }
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _nameController.text = widget.item.name;
      }
    });
  }

  void _applyDisplayName() {
    final nextName = _nameController.text.trim();
    if (nextName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상품명을 비워둘 수 없어요')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      widget.item.name = nextName;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final originalName = item.originalRecognizedName?.trim();
    final hasOriginalName = originalName != null && originalName.isNotEmpty;
    final showOriginalName =
        hasOriginalName && originalName != item.name.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CartlyRadii.card),
        color: _expanded ? CartlyColors.surface2 : CartlyColors.surface1,
        border: Border.all(
          color: _expanded ? CartlyColors.lineWarm : CartlyColors.line,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(CartlyRadii.control),
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CartlyColors.textPrimary,
                            height: 1.25,
                          ),
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _expanded
                                    ? CartlyColors.softPink
                                    : CartlyColors.surface1,
                                borderRadius: BorderRadius.circular(
                                  CartlyRadii.pill,
                                ),
                                border: Border.all(
                                  color: _expanded
                                      ? CartlyColors.lineWarm
                                      : CartlyColors.line,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                _expanded ? '이름 수정 중' : '이름 수정',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _expanded
                                      ? CartlyColors.brand
                                      : CartlyColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            CartlySymbolIcon.sf(
                              _expanded ? 'chevron.up' : 'chevron.down',
                              size: CartlyIconSizes.inline,
                              color: CartlyColors.textTertiary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '₩${formatPrice(item.totalPrice)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: CartlyColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: CartlyColors.surface1,
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                  border: Border.all(color: CartlyColors.line, width: 0.5),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const CartlySymbolIcon.sf(
                        'minus',
                        size: CartlyIconSizes.inline,
                      ),
                      onPressed: decrease,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CartlyColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const CartlySymbolIcon.sf(
                        'plus',
                        size: CartlyIconSizes.inline,
                      ),
                      onPressed: increase,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '수량 조정',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: CartlyColors.textSecondary,
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            const Text(
              '표시되는 상품명',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CartlyColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              minLines: 1,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _applyDisplayName(),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: CartlyColors.surface1,
                hintText: '상품명을 수정해보세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                  borderSide: const BorderSide(color: CartlyColors.lineStrong),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                  borderSide: const BorderSide(color: CartlyColors.lineStrong),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                  borderSide: const BorderSide(color: CartlyColors.brand),
                ),
              ),
            ),
            if (showOriginalName) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CartlyColors.surface1,
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                  border: Border.all(color: CartlyColors.lineWarm, width: 0.5),
                ),
                child: Text(
                  '인식 원본명: $originalName',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: CartlyColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    _nameController.text = item.name;
                    _toggleExpanded();
                  },
                  style: CartlyButtonStyles.quiet(
                    foregroundColor: CartlyColors.textSecondary,
                  ),
                  child: const Text('접기'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _applyDisplayName,
                  style: CartlyButtonStyles.primary(),
                  child: const Text('상품명 적용'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
