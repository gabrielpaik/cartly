import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/saved_cart.dart';
import '../pages/login_page.dart';
import '../pages/my_page.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/cart_store.dart';
import '../services/cart_title_formatter.dart';
import '../services/household_store.dart';
import 'cartly_symbol_icon.dart';
import 'inline_promo_slot.dart';
import 'saved_cart_list_card.dart';

class SavedTabListEntry extends StatefulWidget {
  final SavedCart cart;
  final int index;
  final VoidCallback onTap;

  const SavedTabListEntry({
    super.key,
    required this.cart,
    required this.index,
    required this.onTap,
  });

  @override
  State<SavedTabListEntry> createState() => _SavedTabListEntryState();
}

class _SavedTabListEntryState extends State<SavedTabListEntry>
    with SingleTickerProviderStateMixin {
  late final SlidableController _slidableController;

  static const _cardRadius = 16.0;

  @override
  void initState() {
    super.initState();
    _slidableController = SlidableController(this)
      ..animation.addListener(_handleSlideChanged);
  }

  @override
  void dispose() {
    _slidableController.animation.removeListener(_handleSlideChanged);
    _slidableController.dispose();
    super.dispose();
  }

  void _handleSlideChanged() {
    if (mounted) setState(() {});
  }

  BorderRadius get _cardBorderRadius {
    final revealDeleteAction = _slidableController.ratio < -0.02;
    if (!revealDeleteAction) {
      return BorderRadius.circular(_cardRadius);
    }

    return const BorderRadius.only(
      topLeft: Radius.circular(_cardRadius),
      bottomLeft: Radius.circular(_cardRadius),
      topRight: Radius.zero,
      bottomRight: Radius.zero,
    );
  }

  Future<void> _handleShareTap(BuildContext context) async {
    final session = AuthStore.instance.session.value;
    if (session == null || session.isGuest) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('회원가입이 필요해요'),
          content: const Text('가족과 지난 카트를 공유하려면 먼저 회원가입이 필요해요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('회원가입하기'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const LoginPage(preferSignup: true),
          ),
        );
      }
      return;
    }
    if (!widget.cart.viewerCanEdit) {
      return;
    }
    await HouseholdStore.instance.refresh();
    if (!context.mounted) return;
    if (!HouseholdStore.instance.state.value.hasHousehold) {
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsAndHouseholdPage()),
      );
      return;
    }

    final nextShared = !widget.cart.isSharedWithHousehold;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(nextShared ? '가족 공유 켜기' : '가족 공유 끄기'),
        content: Text(
          nextShared ? '이 지난 카트를 가족에게 공유할까요?' : '이 지난 카트를 개인 카트로 전환할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await CartStore.instance.setHouseholdShare(
        cartId: widget.cart.id,
        shareWithHousehold: nextShared,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nextShared ? '가족 공유로 전환했어요' : '개인 카트로 전환했어요')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _deleteCart(BuildContext context) async {
    final title = normalizeCartTitleForDisplay(widget.cart.title) ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('지난 카트 삭제'),
          content: Text(
            title.isEmpty ? '이 지난 카트를 삭제할까요?' : '`$title` 카트를 삭제할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE31837),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await CartStore.instance.deleteCart(widget.cart.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('지난 카트를 삭제했어요')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = widget.cart.viewerCanEdit;
    return Column(
      children: [
        Slidable(
          key: ValueKey('saved-cart-${widget.cart.id}'),
          controller: _slidableController,
          endActionPane: canDelete
              ? ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.26,
                  children: [
                    CustomSlidableAction(
                      onPressed: (_) => _deleteCart(context),
                      backgroundColor: const Color(0xFFE31837),
                      foregroundColor: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(_cardRadius),
                        bottomRight: Radius.circular(_cardRadius),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CartlySymbolIcon.sf(
                            'trash.fill',
                            color: Colors.white,
                          ),
                          SizedBox(height: 4),
                          Text('삭제'),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
          child: SavedCartListCard(
            cart: widget.cart,
            onTap: widget.onTap,
            borderRadius: _cardBorderRadius,
            onShareTap: widget.cart.viewerCanEdit
                ? () => _handleShareTap(context)
                : null,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.index == 0)
          InlinePromoSlot(
            slotKey: 'saved_inline_1',
            title: AppRuntimeCopy.text([
              'saved',
              'adFallbackTitle',
            ], '오늘의 혜택 추천'),
            message: AppRuntimeCopy.text([
              'saved',
              'adFallbackMessage',
            ], '저장 카트 확인을 방해하지 않는 위치에 작고 자연스러운 혜택 슬롯을 둬요.'),
            height: 104,
          ),
        if (widget.index == 2)
          InlinePromoSlot(
            slotKey: 'saved_inline_2',
            title: AppRuntimeCopy.text([
              'saved',
              'adSecondaryFallbackTitle',
            ], '비슷한 상품 프로모션'),
            message: AppRuntimeCopy.text([
              'saved',
              'adSecondaryFallbackMessage',
            ], '히스토리를 보는 흐름은 유지하고, 목록 사이에만 낮은 밀도로 노출해요.'),
            height: 104,
          ),
      ],
    );
  }
}
