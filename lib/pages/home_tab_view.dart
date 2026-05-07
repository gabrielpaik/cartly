import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../app_support.dart';
import '../models/recognized_item.dart';
import '../services/app_runtime_copy.dart';
import '../services/scan_repository.dart';
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
          AppRuntimeCopy.text(['home', 'subtitle'], '지금 담은 상품과 합계를 한눈에 확인해보세요'),
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
          ], '스캔하거나 직접 담아보세요'),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 20),
        SectionHeader(
          title: AppRuntimeCopy.text(['home', 'currentCartTitle'], '현재 카트'),
          subtitle: AppRuntimeCopy.text([
            'home',
            'currentCartSubtitle',
          ], '지금 담은 상품과 합계를 확인해보세요'),
        ),
        const SizedBox(height: 10),
        CurrentCartSection(
          items: items,
          onRemove: onRemove,
          onChanged: onChangeCurrentCartItem,
        ),
        const SizedBox(height: 20),
        Text(
          '탐색에서 도움 받기',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black45,
          ),
        ),
      ],
    );
  }
}
