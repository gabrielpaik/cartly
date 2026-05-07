import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';

class LoginPageHeaderSection extends StatelessWidget {
  final String? loginHeroImageUrl;
  final String title;
  final String subtitle;

  const LoginPageHeaderSection({
    super.key,
    required this.loginHeroImageUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final heroUrl = loginHeroImageUrl?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heroUrl != null && heroUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(CartlyRadii.card),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                heroUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: CartlySpacing.section),
        ],
        Text(
          title,
          style: CartlyText.pageHeroCompact.copyWith(
            fontSize: 28,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: CartlyText.pageSubtitle),
      ],
    );
  }
}
