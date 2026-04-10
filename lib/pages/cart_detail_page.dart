import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/saved_cart.dart';
import '../services/admob_service.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../widgets/cart_detail_bottom_bar.dart';
import '../widgets/cart_detail_guest_retention_section.dart';
import '../widgets/cart_detail_item_tile.dart';
import '../widgets/saved_cart_item_add_section.dart';

final _cartPriceFormatter = NumberFormat('#,###');
String _fmt(int v) => _cartPriceFormatter.format(v);

class CartDetailPage extends StatefulWidget {
  final SavedCart cart;
  const CartDetailPage({super.key, required this.cart});

  @override
  State<CartDetailPage> createState() => _CartDetailPageState();
}

class _CartDetailPageState extends State<CartDetailPage> {
  late SavedCart _cart;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isExtendingRetention = false;

  int? _editingIndex;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cart = SavedCart(
      id: widget.cart.id,
      title: widget.cart.title,
      createdAt: widget.cart.createdAt,
      expiresAt: widget.cart.expiresAt,
      isExpired: widget.cart.isExpired,
      retentionExtensionCount: widget.cart.retentionExtensionCount,
      canExtendRetention: widget.cart.canExtendRetention,
      items: widget.cart.items
          .map(
            (e) => SavedCartItem(
              name: e.name,
              price: e.price,
              quantity: e.quantity,
            ),
          )
          .toList(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  bool get _isExpiredGuestLocked {
    final session = AuthStore.instance.session.value;
    return _cart.isExpired && session != null && session.isGuest;
  }

  void _toggleEditMode() {
    if (_isSaving || _isExpiredGuestLocked) return;
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _editingIndex = null;
      }
    });
  }

  void _openInlineEditor(int index) {
    final it = _cart.items[index];
    setState(() {
      _editingIndex = index;
      _nameCtrl.text = it.name;
      _priceCtrl.text = it.price.toString();
    });
  }

  void _closeInlineEditor() {
    setState(() => _editingIndex = null);
  }

  void _applyInlineEdits() {
    final i = _editingIndex;
    if (i == null) return;

    final newName = _nameCtrl.text.trim();
    final newPrice =
        int.tryParse(_priceCtrl.text.replaceAll(',', '').trim()) ?? 0;

    if (newName.isEmpty || newPrice <= 0) {
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

    setState(() {
      _cart.items[i].name = newName;
      _cart.items[i].price = newPrice;
      _editingIndex = null;
    });
  }

  void _increase(int i) => setState(() => _cart.items[i].quantity++);

  void _decrease(int i) {
    setState(() {
      if (_cart.items[i].quantity > 1) _cart.items[i].quantity--;
    });
  }

  Future<void> _save() async {
    if (_isSaving || _isExpiredGuestLocked) return;

    for (final it in _cart.items) {
      it.name = it.name.trim();
      if (it.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppRuntimeCopy.text([
                'cartDetail',
                'validation',
                'nameRequired',
              ], '상품명이 비어있어요'),
            ),
          ),
        );
        return;
      }
      if (it.price <= 0 || it.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppRuntimeCopy.text([
                'cartDetail',
                'validation',
                'priceQuantityRequired',
              ], '가격/수량을 확인해주세요'),
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final savedSnapshot = await CartStore.instance.updateCart(_cart);
      if (!mounted) return;

      setState(() {
        _cart = SavedCart(
          id: savedSnapshot.id,
          title: savedSnapshot.title,
          createdAt: savedSnapshot.createdAt,
          expiresAt: savedSnapshot.expiresAt,
          isExpired: savedSnapshot.isExpired,
          retentionExtensionCount: savedSnapshot.retentionExtensionCount,
          canExtendRetention: savedSnapshot.canExtendRetention,
          items: savedSnapshot.items
              .map(
                (e) => SavedCartItem(
                  name: e.name,
                  price: e.price,
                  quantity: e.quantity,
                ),
              )
              .toList(),
        );
        _isEditing = false;
        _editingIndex = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppRuntimeCopy.text([
              'cartDetail',
              'savedSnapshotDone',
            ], '새 저장본으로 기록했어요'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _extendRetention() async {
    if (_isExtendingRetention) return;

    final session = AuthStore.instance.session.value;
    if (session == null || !session.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게스트 카트만 저장 기간을 연장할 수 있어요')),
      );
      return;
    }

    setState(() => _isExtendingRetention = true);
    try {
      final result = await AdMobService.instance.showGuestRetentionRewarded();
      if (!mounted) return;
      if (result != RewardedAdResult.rewarded) {
        final message = switch (result) {
          RewardedAdResult.dismissed => '광고를 끝까지 봐야 카트가 다시 열려요',
          RewardedAdResult.unavailable => '지금은 광고를 불러오지 못했어요. 잠시 후 다시 시도해주세요',
          RewardedAdResult.failedToShow => '광고를 여는 데 실패했어요. 잠시 후 다시 시도해주세요',
          RewardedAdResult.rewarded => null,
        };
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        return;
      }

      final updated = await CartStore.instance.extendRetention(_cart.id);
      if (!mounted) return;

      setState(() => _cart = updated);
      final expiryText = updated.expiresAt == null
          ? '저장 기간을 연장했어요'
          : '저장 기간이 ${DateFormat('M월 d일').format(updated.expiresAt!)}까지 연장됐어요';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(expiryText)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isExtendingRetention = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Text(
                  AppRuntimeCopy.text([
                    'cartDetail',
                    'deleteDialogTitle',
                  ], '이 카트를 삭제할까요?'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppRuntimeCopy.text([
                    'cartDetail',
                    'deleteDialogBody',
                  ], '삭제하면 되돌릴 수 없어요.'),
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          AppRuntimeCopy.text([
                            'cartDetail',
                            'deleteCancel',
                          ], '취소'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE31837),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          AppRuntimeCopy.text([
                            'cartDetail',
                            'deleteConfirm',
                          ], '삭제'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true) return;

    await CartStore.instance.deleteCart(_cart.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _addItem(String name, int price) {
    if (_isExpiredGuestLocked) return;

    setState(() {
      _cart.items.add(SavedCartItem(name: name, price: price, quantity: 1));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppRuntimeCopy.text(['cartDetail', 'itemAdded'], '상품을 추가했어요'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('M월 d일').format(_cart.createdAt);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: false,
        title: Text(
          '$dateText ${AppRuntimeCopy.text(['cartDetail', 'titleSuffix'], '카트')}',
        ),
        actions: [
          if (!_isExpiredGuestLocked)
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(
                _isEditing
                    ? AppRuntimeCopy.text(['cartDetail', 'done'], '완료')
                    : AppRuntimeCopy.text(['cartDetail', 'edit'], '수정'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          if (_isEditing && !_isExpiredGuestLocked)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CartDetailGuestRetentionSection(
              cart: _cart,
              isExtendingRetention: _isExtendingRetention,
              onExtendRetention: _extendRetention,
            ),
            Expanded(
              child: _isExpiredGuestLocked
                  ? CartDetailGuestLockedView(
                      canExtendRetention: _cart.canExtendRetention,
                    )
                  : _cart.items.isEmpty
                      ? Center(
                          child: Text(
                            AppRuntimeCopy.text([
                              'cartDetail',
                              'empty',
                            ], '카트가 비었어요'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _cart.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _cart.items[index];
                            final editing = _editingIndex == index;

                            return CartDetailItemTile(
                              item: item,
                              isEditingMode: _isEditing,
                              isInlineEditing: editing,
                              priceText: '₩${_fmt(item.price)}',
                              nameController: _nameCtrl,
                              priceController: _priceCtrl,
                              onEdit: _isEditing
                                  ? () => _openInlineEditor(index)
                                  : null,
                              onDelete: _isEditing
                                  ? () {
                                      setState(() => _cart.items.removeAt(index));
                                    }
                                  : null,
                              onDecrease: _isEditing && !editing
                                  ? () => _decrease(index)
                                  : null,
                              onIncrease: _isEditing && !editing
                                  ? () => _increase(index)
                                  : null,
                              onCancelInlineEdit: _closeInlineEditor,
                              onApplyInlineEdit: _applyInlineEdits,
                            );
                          },
                        ),
            ),
            if (!_isExpiredGuestLocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SavedCartItemAddSection(
                  isEditing: _isEditing,
                  onAdd: _addItem,
                ),
              ),
            if (!_isExpiredGuestLocked)
              CartDetailBottomBar(
                totalPriceText: '₩${_fmt(_cart.totalPrice)}',
                isSaving: _isSaving,
                onSave: _save,
              ),
          ],
        ),
      ),
    );
  }
}
