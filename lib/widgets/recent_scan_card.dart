import 'package:flutter/material.dart';

import '../app_support.dart';
import '../services/app_runtime_copy.dart';

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
