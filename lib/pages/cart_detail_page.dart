import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/saved_cart.dart';
import '../services/admob_service.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import 'cart_detail_page_helpers.dart';
import '../widgets/cart_detail_app_bar_actions.dart';
import '../widgets/cart_detail_body.dart';
import '../widgets/cart_detail_delete_confirmation_sheet.dart';
import '../widgets/cart_detail_edit_actions_section.dart';
import '../widgets/cart_detail_guest_retention_section.dart';

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
    _cart = cloneSavedCartSnapshot(widget.cart);
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
    final validationMessage = cartDetailInlineEditValidationMessage(
      nameText: _nameCtrl.text,
      priceText: _priceCtrl.text,
    );

    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
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

    final validationMessage = cartDetailSaveValidationMessage(_cart.items);
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final savedSnapshot = await CartStore.instance.updateCart(_cart);
      if (!mounted) return;

      setState(() {
        _cart = cloneSavedCartSnapshot(savedSnapshot);
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
        final message = cartDetailRetentionResultMessage(result);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cartDetailRetentionExtendedMessage(updated))),
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
    final ok = await showCartDetailDeleteConfirmationSheet(context);

    if (ok != true) return;

    await CartStore.instance.deleteCart(_cart.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _addItem(String name, int price) {
    if (_isExpiredGuestLocked) return;

    setState(() {
      _cart.items.add(
        SavedCartItem(
          name: name,
          price: price,
          quantity: 1,
          source: 'manual',
        ),
      );
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
          CartDetailAppBarActions(
            isEditing: _isEditing,
            isExpiredGuestLocked: _isExpiredGuestLocked,
            onToggleEditMode: _toggleEditMode,
            onDelete: _confirmDelete,
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
              child: CartDetailBody(
                isExpiredGuestLocked: _isExpiredGuestLocked,
                canExtendRetention: _cart.canExtendRetention,
                items: _cart.items,
                isEditing: _isEditing,
                editingIndex: _editingIndex,
                nameController: _nameCtrl,
                priceController: _priceCtrl,
                formatPriceText: (price) => '₩${_fmt(price)}',
                onEdit: _openInlineEditor,
                onDelete: (index) {
                  setState(() => _cart.items.removeAt(index));
                },
                onDecrease: _decrease,
                onIncrease: _increase,
                onCancelInlineEdit: _closeInlineEditor,
                onApplyInlineEdit: _applyInlineEdits,
              ),
            ),
            CartDetailEditActionsSection(
              isVisible: !_isExpiredGuestLocked,
              isEditing: _isEditing,
              onAddItem: _addItem,
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
