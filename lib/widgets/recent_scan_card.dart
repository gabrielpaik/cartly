import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import '../app_support.dart';
import '../services/app_runtime_copy.dart';

String _scanText(String key, String fallback) =>
    AppRuntimeCopy.text(['scan', key], fallback);

class RecentScanCarousel extends StatelessWidget {
  final List<RecentScanEntry> entries;
  final ValueChanged<RecentScanEntry>? onAdd;
  final ValueChanged<RecentScanEntry>? onDismiss;

  const RecentScanCarousel({
    super.key,
    required this.entries,
    this.onAdd,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _scanText('recentQueueTitle', '검토 대기함'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _scanText('recentQueueSubtitle', '방금 읽은 결과를 차례대로 정리해요'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(entries.length, (index) {
            final entry = entries[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == entries.length - 1 ? 0 : 8,
              ),
              child: _RecentScanInboxRow(
                entry: entry,
                index: index,
                total: entries.length,
                onAdd: onAdd == null ? null : () => onAdd!(entry),
                onDismiss: onDismiss == null ? null : () => onDismiss!(entry),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RecentScanInboxRow extends StatelessWidget {
  final RecentScanEntry entry;
  final int index;
  final int total;
  final VoidCallback? onAdd;
  final VoidCallback? onDismiss;

  const _RecentScanInboxRow({
    required this.entry,
    required this.index,
    required this.total,
    this.onAdd,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final confidence = item.confidence == null
        ? null
        : (item.confidence! * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CartlyColors.surface1,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  total > 1
                      ? _scanText('queuePosition', '대기 ${index + 1}/$total')
                      : _scanText('recentReady', '등록 대기'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB26A00),
                  ),
                ),
              ),
              const Spacer(),
              if (confidence != null)
                Text(
                  '신뢰 $confidence%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatPrice(item.price),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_scanText('recentDismiss', '지우기')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE31837),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_scanText('recentAddToCart', '카트에 담기')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
