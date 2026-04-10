import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';
import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../services/app_runtime_copy.dart';
import '../services/cart_store.dart';
import '../services/scan_repository.dart';
import '../widgets/current_cart_section.dart';
import '../widgets/item_add_section.dart';

class HomeTabView extends StatelessWidget {
  final List<CameraDescription> cameras;
  final ScanRepository scanRepository;
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final void Function(RecognizedItem item) onRecognized;
  final void Function(RecognizedItem item) onAdd;
  final void Function(CartItem item) onRemove;

  const HomeTabView({
    super.key,
    required this.cameras,
    required this.scanRepository,
    required this.items,
    required this.recentScans,
    required this.onRecognized,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text(
          AppRuntimeCopy.text(['home', 'pageTitle'], 'Cartly'),
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
            height: 0.95,
            color: Color(0xFFE31837),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppRuntimeCopy.text(['home', 'subtitle'], '지금 카트 총액을 확인해'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: AppRuntimeCopy.text(['home', 'addSectionTitle'], '새 상품 추가'),
          subtitle: AppRuntimeCopy.text([
            'home',
            'addSectionSubtitle',
          ], '스캔하거나 바로 담기'),
        ),
        const SizedBox(height: 10),
        ItemAddSection(
          key: const ValueKey('home-item-add-section'),
          cameras: cameras,
          scanRepository: scanRepository,
          onRecognized: onRecognized,
          onAdd: (item) {
            onAdd(item);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppRuntimeCopy.text([
                    'home',
                    'addToCurrentCartDone',
                  ], '현재 카트에 담았어요'),
                ),
              ),
            );
          },
          addButtonText: AppRuntimeCopy.text([
            'home',
            'addToCurrentCartButton',
          ], '현재 카트에 담기'),
        ),
        if (recentScans.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionHeader(
            title: AppRuntimeCopy.text(['home', 'recentScanTitle'], '최근 스캔'),
            subtitle: AppRuntimeCopy.text([
              'home',
              'recentScanSubtitle',
            ], '방금 읽은 결과'),
          ),
          const SizedBox(height: 10),
          ...recentScans.take(3).map((entry) => RecentScanCard(entry: entry)),
        ],
        const SizedBox(height: 20),
        SectionHeader(
          title: AppRuntimeCopy.text(['home', 'currentCartTitle'], '현재 카트'),
          subtitle: AppRuntimeCopy.text([
            'home',
            'currentCartSubtitle',
          ], '결제 전 합계를 확인해'),
        ),
        const SizedBox(height: 10),
        CurrentCartSection(items: items, onRemove: onRemove),
        const SizedBox(height: 20),
        ValueListenableBuilder<List<SavedCart>>(
          valueListenable: CartStore.instance.carts,
          builder: (context, carts, _) {
            return RecentSavedPreviewCard(
              cart: carts.isEmpty ? null : carts.first,
            );
          },
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class RecentSavedPreviewCard extends StatelessWidget {
  final SavedCart? cart;

  const RecentSavedPreviewCard({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    if (cart == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppRuntimeCopy.text(['saved', 'recentTitle'], '최근 저장 카트'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              AppRuntimeCopy.text([
                'saved',
                'recentEmptyBody',
              ], '아직 저장된 카트가 없어요. 현재 카트를 저장하면 다음 쇼핑 전에 다시 꺼내볼 수 있어요.'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final dateText = DateFormat('M월 d일').format(cart!.createdAt);
    final title = (cart!.title ?? '').trim();
    final preview = cart!.items.take(2).map((e) => e.name).join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => CartDetailPage(cart: cart!)));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty
                        ? AppRuntimeCopy.text(['saved', 'recentTitle'], '최근 저장 카트')
                        : title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                if (cart!.isExpired)
                  const ContextPill(label: '만료됨', color: Color(0xFFE31837)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$dateText · ${cart!.totalCount}개 · ₩${formatPrice(cart!.totalPrice)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentScanCard extends StatelessWidget {
  final RecentScanEntry entry;

  const RecentScanCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final confidence = item.confidence;
    final confidenceText = confidence == null
        ? AppRuntimeCopy.text(['scan', 'confidence', 'none'], '신뢰도 없음')
        : '${(confidence * 100).round()}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '₩${formatPrice(item.price)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${AppRuntimeCopy.text(['home', 'recentRecognizedPrefix'], '최근 인식')} · $confidenceText',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class ContextPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? background;

  const ContextPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class TotalBar extends StatelessWidget {
  final int totalPrice;
  final VoidCallback onSave;
  final bool isSaving;

  const TotalBar({
    super.key,
    required this.totalPrice,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE31837),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppRuntimeCopy.text(['home', 'cartTotalLabel'], '현재 카트 합계'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₩${formatPrice(totalPrice)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSaving ? null : onSave,
              child: Text(
                isSaving
                    ? AppRuntimeCopy.text(['common', 'loading'], '처리 중…')
                    : AppRuntimeCopy.text(['home', 'saveCartButton'], '카트 저장'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
