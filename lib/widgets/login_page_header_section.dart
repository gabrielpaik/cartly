import 'package:flutter/material.dart';

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
            borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 18),
        ],
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
            height: 0.95,
            color: Color(0xFFE31837),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
