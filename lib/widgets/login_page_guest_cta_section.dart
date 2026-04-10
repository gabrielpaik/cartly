import 'package:flutter/material.dart';

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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefitsTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                benefitsBody,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
