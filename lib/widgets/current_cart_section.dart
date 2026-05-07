import 'package:flutter/material.dart';

import '../app_support.dart';
import '../services/app_runtime_copy.dart';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Opacity(
                opacity: 0.14,
                child: Icon(
                  Icons.shopping_cart_outlined,
                  size: 72,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppRuntimeCopy.text([
                  'home',
                  'currentCartEmpty',
                ], '아직 담은 상품이 없어요'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                ),
              ),
            ],
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
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
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
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _toggleExpanded,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: _expanded ? null : 1,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: decrease,
                  ),
                  Text('${item.quantity}'),
                  IconButton(icon: const Icon(Icons.add), onPressed: increase),
                  const SizedBox(width: 8),
                  Text(
                    '₩${formatPrice(item.totalPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            Text(
              '표시되는 상품명',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
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
                fillColor: Colors.white,
                hintText: '상품명을 수정해보세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
              ),
            ),
            if (showOriginalName) ...[
              const SizedBox(height: 10),
              Text(
                '인식 원본명: $originalName',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  height: 1.4,
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
                  child: const Text('접기'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _applyDisplayName,
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
