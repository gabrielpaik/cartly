import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/saved_cart.dart';
import '../services/admob_service.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../app/cartly_ui.dart';
import 'cart_detail_page_helpers.dart';
import 'receipt_comparison_page.dart';
import '../widgets/cart_detail_app_bar_actions.dart';
import '../widgets/cart_detail_body.dart';
import '../widgets/cart_detail_delete_confirmation_sheet.dart';
import '../widgets/cart_detail_edit_actions_section.dart';
import '../widgets/cart_detail_guest_retention_section.dart';
import '../widgets/cartly_symbol_icon.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCartFromStore();
    });
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _extendRetention() async {
    if (_isExtendingRetention) return;

    final session = AuthStore.instance.session.value;
    if (session == null || !session.isGuest) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('게스트 카트만 저장 기간을 연장할 수 있어요')));
      return;
    }

    setState(() => _isExtendingRetention = true);
    try {
      final result = await AdMobService.instance.showGuestRetentionRewarded();
      if (!mounted) return;
      if (result != RewardedAdResult.rewarded) {
        final message = cartDetailRetentionResultMessage(result);
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isExtendingRetention = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showCartDetailDeleteConfirmationSheet(context);

    if (ok != true) return;

    try {
      await CartStore.instance.deleteCart(_cart.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _addItem(String name, int price) {
    if (_isExpiredGuestLocked) return;

    setState(() {
      _cart.items.add(
        SavedCartItem(name: name, price: price, quantity: 1, source: 'manual'),
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

  Future<void> _refreshCartFromStore() async {
    final refreshed = await CartStore.instance.refreshCartById(_cart.id);
    if (!mounted || refreshed == null) return;
    setState(() {
      _cart = cloneSavedCartSnapshot(refreshed);
    });
  }

  Future<void> _openReceiptCompare() async {
    if (_isEditing || _isSaving || _isExpiredGuestLocked) return;

    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ReceiptCheckPage(cart: _cart)));

    if (!mounted) return;
    if (result is SavedCart) {
      setState(() {
        _cart = cloneSavedCartSnapshot(result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영수증 기준으로 카트를 반영했어요')),
      );
      return;
    }

    await _refreshCartFromStore();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('M월 d일').format(_cart.createdAt);

    return Scaffold(
      backgroundColor: CartlyColors.surface0,
      appBar: AppBar(
        backgroundColor: CartlyColors.surface0,
        elevation: 0,
        surfaceTintColor: CartlyColors.surface0,
        foregroundColor: CartlyColors.textPrimary,
        centerTitle: false,
        title: Text(
          '$dateText ${AppRuntimeCopy.text(['cartDetail', 'titleSuffix'], '카트')}',
        ),
        actions: [
          CartDetailAppBarActions(
            isEditing: _isEditing,
            isExpiredGuestLocked: _isExpiredGuestLocked,
            receiptStatus: _cart.receiptStatus,
            onToggleEditMode: _toggleEditMode,
            onDelete: _confirmDelete,
            onReceiptCompare: _openReceiptCompare,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CartDetailGuestRetentionSection(
              cart: _cart,
              isExtendingRetention: _isExtendingRetention,
              onExtendRetention: _extendRetention,
            ),
            Expanded(
              child: Column(
                children: [
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: CartStore.instance.pendingCartIds,
                    builder: (context, pendingCartIds, _) {
                      if (!pendingCartIds.contains(_cart.id)) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: const Text(
                          '이 카트는 서버 동기화 대기 중이야. 연결되면 다시 시도할게.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                            height: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_cart.receiptStatus != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _CartReceiptStatusCard(
                        status: _cart.receiptStatus!,
                        onTap: _openReceiptCompare,
                      ),
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
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CartDetailEditActionsSection(
        isVisible: !_isExpiredGuestLocked,
        isEditing: _isEditing,
        onAddItem: _addItem,
        totalPriceText: '₩${_fmt(_cart.totalPrice)}',
        isSaving: _isSaving,
        onSave: _save,
      ),
    );
  }
}

class _CartReceiptStatusCard extends StatelessWidget {
  final SavedCartReceiptStatus status;
  final VoidCallback onTap;

  const _CartReceiptStatusCard({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (
      badgeText,
      badgeColor,
      badgeForeground,
      bodyText,
    ) = switch (status.receiptStatus) {
      'processing' => (
        '처리 중',
        const Color(0xFFE0F2FE),
        const Color(0xFF0369A1),
        '영수증 요약과 상세 내역을 준비하고 있어요.',
      ),
      'failed' => (
        '분석 실패',
        const Color(0xFFFDECEC),
        const Color(0xFFB42318),
        '영수증을 다시 올려서 한 번 더 정리해 주세요.',
      ),
      'ready' => (
        '영수증 정리됨',
        const Color(0xFFEAF7EE),
        const Color(0xFF2E7D32),
        '영수증 요약과 상세 내역을 다시 열어볼 수 있어요.',
      ),
      _ => (
        '영수증 등록됨',
        const Color(0xFFF3F4F6),
        const Color(0xFF374151),
        '영수증이 저장돼 있어요. 다시 열어서 확인할 수 있어요.',
      ),
    };

    return Material(
      color: CartlyColors.surface1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeForeground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      status.merchantName?.trim().isNotEmpty == true
                          ? status.merchantName!.trim()
                          : '이 카트에 연결된 영수증',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bodyText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const CartlySymbolIcon.sf('chevron.right'),
            ],
          ),
        ),
      ),
    );
  }
}
