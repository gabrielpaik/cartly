import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/app_config_store.dart';

const _bundledCartlyLogoAsset =
    'assets/images/branding/cartly_logo_vectorized.svg';
const _cartlyBrandRed = Color(0xFFE31837);

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
    final height = fontSize + 10;
    final isSvg = trimmed.toLowerCase().split('?').first.endsWith('.svg');
    final placeholder = _logoPlaceholder(trimmed, fallbackText, height);
    final logoColorFilter = _logoColorFilter(trimmed);
    if (isSvg) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: SvgPicture.network(
          trimmed,
          fit: BoxFit.fitHeight,
          alignment: Alignment.centerLeft,
          colorFilter: logoColorFilter,
          placeholderBuilder: (_) => placeholder,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Image.network(
        trimmed,
        fit: BoxFit.fitHeight,
        alignment: Alignment.centerLeft,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }

  Widget _logoPlaceholder(String url, String fallbackText, double height) {
    if (_isBundledCartlyLogo(url)) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: SvgPicture.asset(
          _bundledCartlyLogoAsset,
          fit: BoxFit.fitHeight,
          alignment: Alignment.centerLeft,
          colorFilter: _logoColorFilter(url),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: _textLogo(fallbackText),
    );
  }

  bool _isBundledCartlyLogo(String url) {
    final lowerPath =
        Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return lowerPath.endsWith('cartly_logo_vectorized.svg');
  }

  ColorFilter? _logoColorFilter(String url) {
    if (!_isBundledCartlyLogo(url)) {
      return null;
    }
    return const ColorFilter.mode(_cartlyBrandRed, BlendMode.srcIn);
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
