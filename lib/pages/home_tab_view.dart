import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import '../app_support.dart';
import '../models/recognized_item.dart';
import '../services/app_runtime_copy.dart';
import '../services/scan_repository.dart';
import '../widgets/brand_mark.dart';
import '../widgets/cartly_action_tile.dart';
import '../widgets/cartly_page_header.dart';
import '../widgets/cartly_symbol_icon.dart';
import '../widgets/current_cart_section.dart';
import '../widgets/item_add_section.dart';
import '../widgets/recent_scan_card.dart';
import '../widgets/section_header.dart';

class HomeTabView extends StatelessWidget {
  final List<CameraDescription> cameras;
  final ScanRepository scanRepository;
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final void Function(RecognizedItem item) onRecognized;
  final Future<bool> Function(RecognizedItem item) onAdd;
  final void Function(RecognizedItem item) onDismissRecognized;
  final Future<bool> Function(RecentScanEntry entry) onAddRecentScan;
  final void Function(RecentScanEntry entry) onDismissRecentScan;
  final void Function(CartItem item) onRemove;
  final void Function(CartItem item) onChangeCurrentCartItem;
  final VoidCallback onGoExplore;
  final bool isSharedCurrentCartMode;
  final VoidCallback onPersonalCurrentCartTap;
  final VoidCallback onSharedCurrentCartTap;

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
    required this.onChangeCurrentCartItem,
    required this.onGoExplore,
    required this.isSharedCurrentCartMode,
    required this.onPersonalCurrentCartTap,
    required this.onSharedCurrentCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            height: 84,
            child: Align(
              alignment: Alignment.topLeft,
              child: CartlyPageHeader(
                title: const BrandMark(fontSize: 28),
                titleHeight: 40,
                subtitleHeight: 24,
                subtitle: AppRuntimeCopy.text([
                  'home',
                  'subtitle',
                ], '지금 담은 상품과 합계를 한눈에 확인해보세요'),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            CartlySpacing.sectionLoose,
            16,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: AppRuntimeCopy.text([
                  'home',
                  'addSectionTitle',
                ], '새 상품 추가'),
                subtitle: AppRuntimeCopy.text([
                  'home',
                  'addSectionSubtitle',
                ], '스캔하거나 직접 담아보세요'),
              ),
              const SizedBox(height: CartlySpacing.md),
              ItemAddSection(
                key: const ValueKey('home-item-add-section'),
                cameras: cameras,
                scanRepository: scanRepository,
                onRecognized: onRecognized,
                onDismissRecognized: onDismissRecognized,
                onAdd: (item) async {
                  final added = await onAdd(item);
                  if (!context.mounted || !added) return false;
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
                  return true;
                },
                addButtonText: AppRuntimeCopy.text([
                  'home',
                  'addToCurrentCartButton',
                ], '현재 카트에 담기'),
              ),
              if (recentScans.isNotEmpty) ...[
                const SizedBox(height: CartlySpacing.sectionLoose),
                SectionHeader(
                  title: AppRuntimeCopy.text([
                    'home',
                    'recentScanTitle',
                  ], '스캔 보관함'),
                  subtitle: AppRuntimeCopy.text([
                    'home',
                    'recentScanSubtitle',
                  ], '검토 대기 결과를 한 번에 정리해'),
                ),
                const SizedBox(height: CartlySpacing.md),
                RecentScanCarousel(
                  entries: recentScans,
                  onAdd: (entry) {
                    unawaited(() async {
                      final added = await onAddRecentScan(entry);
                      if (!context.mounted || !added) return;
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
                    }());
                  },
                  onDismiss: onDismissRecentScan,
                ),
              ],
              const SizedBox(height: CartlySpacing.sectionLoose),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SectionHeader(
                      title: AppRuntimeCopy.text([
                        'home',
                        'currentCartTitle',
                      ], '현재 카트'),
                      subtitle: AppRuntimeCopy.text([
                        'home',
                        'currentCartSubtitle',
                      ], '지금 담은 상품과 합계를 확인해보세요'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CurrentCartModeSwitch(
                    isShared: isSharedCurrentCartMode,
                    onPersonalTap: onPersonalCurrentCartTap,
                    onSharedTap: onSharedCurrentCartTap,
                  ),
                ],
              ),
              const SizedBox(height: CartlySpacing.md),
              CurrentCartSection(
                items: items,
                onRemove: onRemove,
                onChanged: onChangeCurrentCartItem,
              ),
              const SizedBox(height: CartlySpacing.xl),
              CartlyActionTile(
                icon: const CartlySymbolIcon.sf('sparkle.magnifyingglass'),
                title: AppRuntimeCopy.text([
                  'home',
                  'exploreEntryTitle',
                ], '탐색에서 다음 판단 이어가기'),
                body: AppRuntimeCopy.text([
                  'home',
                  'exploreEntryBody',
                ], '비교 후보와 대안을 한 번에 보고 결정해보세요'),
                onTap: onGoExplore,
                showChevron: true,
                backgroundColor: CartlyColors.surface1,
                iconBackgroundColor: CartlyColors.surface2,
                border: Border.all(color: CartlyColors.line, width: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentCartModeSwitch extends StatelessWidget {
  final bool isShared;
  final VoidCallback onPersonalTap;
  final VoidCallback onSharedTap;

  const _CurrentCartModeSwitch({
    required this.isShared,
    required this.onPersonalTap,
    required this.onSharedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: CartlyColors.surface1,
        borderRadius: BorderRadius.circular(CartlyRadii.pill),
        border: Border.all(color: CartlyColors.line, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrentCartModeChip(
            label: '개인',
            selected: !isShared,
            selectedBackgroundColor: CartlyColors.surface2,
            selectedForegroundColor: CartlyColors.textPrimary,
            onTap: onPersonalTap,
          ),
          _CurrentCartModeChip(
            label: '공유',
            selected: isShared,
            selectedBackgroundColor: CartlyColors.brand,
            selectedForegroundColor: CartlyColors.onBrandPrimary,
            onTap: onSharedTap,
          ),
        ],
      ),
    );
  }
}

class _CurrentCartModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedBackgroundColor;
  final Color selectedForegroundColor;
  final VoidCallback onTap;

  const _CurrentCartModeChip({
    required this.label,
    required this.selected,
    required this.selectedBackgroundColor,
    required this.selectedForegroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedBackgroundColor : Colors.transparent,
      borderRadius: BorderRadius.circular(CartlyRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CartlyRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected
                  ? selectedForegroundColor
                  : CartlyColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
