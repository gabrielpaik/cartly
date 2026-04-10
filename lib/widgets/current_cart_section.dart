import 'package:flutter/material.dart';

import '../app_support.dart';
import '../services/app_runtime_copy.dart';

class CurrentCartSection extends StatelessWidget {
  final List<CartItem> items;
  final void Function(CartItem item) onRemove;

  const CurrentCartSection({
    super.key,
    required this.items,
    required this.onRemove,
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
              key: ValueKey('${item.name}-${item.price}-${item.hashCode}'),
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
              child: CurrentCartItemCard(item: item),
            ),
          )
          .toList(),
    );
  }
}

class CurrentCartItemCard extends StatefulWidget {
  final CartItem item;

  const CurrentCartItemCard({super.key, required this.item});

  @override
  State<CurrentCartItemCard> createState() => _CurrentCartItemCardState();
}

class _CurrentCartItemCardState extends State<CurrentCartItemCard> {
  void increase() => setState(() => widget.item.quantity++);

  void decrease() {
    if (widget.item.quantity > 1) {
      setState(() => widget.item.quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.remove), onPressed: decrease),
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
    );
  }
}
