import 'package:flutter/material.dart';

import '../services/app_runtime_copy.dart';

class SavedTabEmptyState extends StatelessWidget {
  const SavedTabEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Opacity(
              opacity: 0.16,
              child: Icon(Icons.bookmark_border, size: 72),
            ),
            const SizedBox(height: 14),
            Text(
              AppRuntimeCopy.text([
                'saved',
                'emptyTitle',
              ], '아직 저장된 카트가 없어요'),
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
              ], 'Home에서 저장하면 여기서 다시 볼 수 있어.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
