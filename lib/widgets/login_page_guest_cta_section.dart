import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import 'cartly_surface_card.dart';

class LoginPageGuestCtaSection extends StatelessWidget {
  final String benefitsTitle;
  final String benefitsBody;
  final String guestButtonLabel;
  final VoidCallback? onContinueAsGuest;

  const LoginPageGuestCtaSection({
    super.key,
    required this.benefitsTitle,
    required this.benefitsBody,
    required this.guestButtonLabel,
    required this.onContinueAsGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 0),
        CartlySurfaceCard(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          backgroundColor: CartlyColors.surface1,
          border: Border.all(color: CartlyColors.lineWarm, width: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefitsTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: CartlyColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                benefitsBody,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CartlyColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton(
            style: CartlyButtonStyles.quiet(
              foregroundColor: CartlyColors.textPrimary,
            ),
            onPressed: onContinueAsGuest,
            child: Text(
              guestButtonLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
