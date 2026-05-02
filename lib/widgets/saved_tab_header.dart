import 'package:flutter/material.dart';

import '../services/app_runtime_copy.dart';
import '../widgets/inline_promo_slot.dart';

class SavedTabHeader extends StatelessWidget {
  const SavedTabHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SavedTabTitle(),
        SizedBox(height: 8),
        _SavedTabSubtitle(),
        SizedBox(height: 20),
        AudienceBannerSlot(
          showForGuests: true,
          showForMembers: true,
        ),
      ],
    );
  }
}

class _SavedTabTitle extends StatelessWidget {
  const _SavedTabTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppRuntimeCopy.text(['saved', 'pageTitle'], '지난 카트'),
      style: const TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 0.95,
        color: Color(0xFFE31837),
      ),
    );
  }
}

class _SavedTabSubtitle extends StatelessWidget {
  const _SavedTabSubtitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppRuntimeCopy.text(['saved', 'subtitle'], '저장한 장보기 기록을 다시 확인해보세요'),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
        height: 1.5,
      ),
    );
  }
}
