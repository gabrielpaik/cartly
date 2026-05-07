import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CartlyText.sectionTitle),
        const SizedBox(height: 5),
        Text(subtitle, style: CartlyText.sectionSubtitle),
      ],
    );
  }
}
