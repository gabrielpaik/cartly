import 'package:flutter/material.dart';

import '../app_support.dart';
import '../services/app_runtime_copy.dart';

String _scanText(String key, String fallback) =>
    AppRuntimeCopy.text(['scan', key], fallback);

class RecentScanCarousel extends StatefulWidget {
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
  State<RecentScanCarousel> createState() => _RecentScanCarouselState();
}

class _RecentScanCarouselState extends State<RecentScanCarousel> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void didUpdateWidget(covariant RecentScanCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.isEmpty) {
      _pageIndex = 0;
      return;
    }
    if (_pageIndex >= widget.entries.length) {
      setState(() {
        _pageIndex = widget.entries.length - 1;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.entries.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) {
              final entry = widget.entries[index];
              return Padding(
                padding: EdgeInsets.only(right: index == widget.entries.length - 1 ? 0 : 10),
                child: _RecentScanActionCard(
                  entry: entry,
                  index: index,
                  total: widget.entries.length,
                  onAdd: widget.onAdd == null ? null : () => widget.onAdd!(entry),
                  onDismiss: widget.onDismiss == null ? null : () => widget.onDismiss!(entry),
                ),
              );
            },
          ),
        ),
        if (widget.entries.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.entries.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _pageIndex == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _pageIndex == index ? const Color(0xFFE31837) : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecentScanActionCard extends StatelessWidget {
  final RecentScanEntry entry;
  final int index;
  final int total;
  final VoidCallback? onAdd;
  final VoidCallback? onDismiss;

  const _RecentScanActionCard({
    required this.entry,
    required this.index,
    required this.total,
    this.onAdd,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final confidence = item.confidence == null ? null : (item.confidence! * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  total > 1
                      ? _scanText('queuePosition', '대기 ${index + 1}/$total')
                      : _scanText('recentReady', '등록 대기'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Spacer(),
              if (confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F6EC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '신뢰 $confidence%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatPrice(item.price),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(_scanText('recentDismiss', '지우기')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE31837),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
