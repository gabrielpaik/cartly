import 'package:flutter/material.dart';

import '../services/app_runtime_copy.dart';
import 'cartly_symbol_icon.dart';

class SavedTabEmptyState extends StatelessWidget {
  final bool compact;

  const SavedTabEmptyState({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: 0.16,
          child: CartlySymbolIcon.sf('bookmark', size: compact ? 56 : 72),
        ),
        SizedBox(height: compact ? 12 : 14),
        Text(
          AppRuntimeCopy.text(['saved', 'emptyTitle'], '아직 저장된 카트가 없어요'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppRuntimeCopy.text([
            'saved',
            'emptyBody',
          ], '홈에서 카트를 저장하면 여기서 다시 볼 수 있어요.'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black45,
            height: 1.45,
          ),
        ),
      ],
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(child: content),
    );
  }
}
