import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
          final image = _networkLogo(
            branding.logoImageUrl!,
            fallbackText: branding.logoText,
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

  Widget _networkLogo(String url, {required String fallbackText}) {
    final trimmed = url.trim();
    final isSvg = trimmed.toLowerCase().split('?').first.endsWith('.svg');
    if (isSvg) {
      return SvgPicture.network(
        trimmed,
        height: fontSize + 14,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => SizedBox(
          height: fontSize + 14,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _textLogo(fallbackText),
          ),
        ),
      );
    }
    return Image.network(
      trimmed,
      height: fontSize + 14,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _textLogo(fallbackText),
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
