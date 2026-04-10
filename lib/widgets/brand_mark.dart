import 'package:flutter/material.dart';

import '../services/app_config_store.dart';

class BrandMark extends StatelessWidget {
  final double fontSize;
  final Color color;

  const BrandMark({
    super.key,
    this.fontSize = 34,
    this.color = const Color(0xFFE31837),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppConfigStore.instance.branding,
      builder: (context, branding, _) {
        final hasImage = branding.logoImageUrl?.isNotEmpty ?? false;
        final logoType = branding.logoType;

        if ((logoType == 'image' || logoType == 'text_image') && hasImage) {
          final image = Image.network(
            branding.logoImageUrl!,
            height: fontSize + 14,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _textLogo(branding.logoText),
          );

          if (logoType == 'text_image') {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                image,
                const SizedBox(width: 10),
                Flexible(child: _textLogo(branding.logoText)),
              ],
            );
          }

          return image;
        }

        return _textLogo(branding.logoText);
      },
    );
  }

  Widget _textLogo(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        height: 0.95,
        color: color,
      ),
    );
  }
}
