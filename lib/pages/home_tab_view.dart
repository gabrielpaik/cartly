import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';
import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';
import '../services/cart_store.dart';
import '../services/scan_repository.dart';
import '../widgets/current_cart_section.dart';
import '../widgets/item_add_section.dart';
import '../widgets/recent_saved_preview_card.dart';
import '../widgets/recent_scan_card.dart';
import '../widgets/section_header.dart';

class HomeTabView extends StatelessWidget {
  final List<CameraDescription> cameras;
  final ScanRepository scanRepository;
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final void Function(RecognizedItem item) onRecognized;
  final void Function(RecognizedItem item) onAdd;
  final void Function(RecognizedItem item) onDismissRecognized;
  final void Function(RecentScanEntry entry) onAddRecentScan;
  final void Function(RecentScanEntry entry) onDismissRecentScan;
  final void Function(CartItem item) onRemove;

  const HomeTabView({
    super.key,
    required this.cameras,
    required this.scanRepository,
    required this.items,
    required this.recentScans,
    required this.onRecognized,
    required this.onAdd,
    required this.onDismissRecognized,
    required this.onAddRecentScan,
    required this.onDismissRecentScan,
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
          onDismissRecognized: onDismissRecognized,
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
            title: AppRuntimeCopy.text(['home', 'recentScanTitle'], '스캔 보관함'),
            subtitle: AppRuntimeCopy.text([
              'home',
              'recentScanSubtitle',
            ], '검토 대기 결과를 한 번에 정리해'),
          ),
          const SizedBox(height: 10),
          RecentScanCarousel(
            entries: recentScans,
            onAdd: onAddRecentScan,
            onDismiss: onDismissRecentScan,
          ),
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
