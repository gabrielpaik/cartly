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
                    _LoginHeaderFallback(title: title),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ] else ...[
          _LoginHeaderFallback(title: title),
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

class _LoginHeaderFallback extends StatelessWidget {
  final String title;

  const _LoginHeaderFallback({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFF1F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_outline, color: Color(0xFFE31837), size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE31837),
            ),
          ),
        ],
      ),
    );
  }
}
