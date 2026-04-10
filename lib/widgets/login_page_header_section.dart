import 'package:flutter/material.dart';

import '../models/app_branding.dart';
import 'brand_mark.dart';

class LoginPageHeaderSection extends StatelessWidget {
  final AppBranding branding;

  const LoginPageHeaderSection({super.key, required this.branding});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (branding.loginHeroImageUrl != null &&
            branding.loginHeroImageUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              branding.loginHeroImageUrl!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
        ],
        const BrandMark(),
        const SizedBox(height: 20),
        Text(
          branding.loginPageTitle,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          branding.loginSubtitle,
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
